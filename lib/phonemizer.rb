# frozen_string_literal: true

require_relative 'phonemizer/version'
require 'open3'
require 'etc'

# A minimal wrap of espeak-ng for simple uses (calls espeak CLI directly).
#
#   apt install espeak-ng        # or brew install espeak-ng
#
# Backend contract (verified against espeak-ng):
#   espeak-ng -q --ipa -v <lang> --stdin
#   espeak-ng merges ALL of stdin into one text and prints the IPA with
#   words space-separated on one line, in input order. Newlines do NOT
#   isolate utterances, so each piece is sent in its own call (its own
#   stdin line) to guarantee per-word isolation. A piece is usually one
#   word, but a multi-word chunk inside one input element (no internal
#   punctuation) stays whole — words within it DO influence each other
#   (liaisons, pronounced final consonants).
module Phonemizer
  module_function

  DEFAULT_LANGUAGE = 'en-us'
  DEFAULT_WORKERS  = [Etc.nprocessors - 1, 1].max

  # espeak emits parenthesized language tags on language switches, e.g.
  # (en) / (fr) / (pt-br); the pattern covers any tag espeak may emit.
  LANG_SWITCH = /\((?:[a-z]{2,3}(?:-[a-z0-9]+)*)\)/

  # Characters espeak would try to pronounce; we split them out instead.
  # Apostrophes are EXCLUDED on purpose: they must stay inside the word
  # they elide (aujourd'hui, l'instar). Splitting on them transcribes the
  # halves separately and drops liaison consonants (oʒuʁdɥi -> oʒuʁ + yi).
  PUNCT = /([[:punct:]&&[^'’‘]]+)/

  # Raised when espeak-ng is missing or fails. Subclasses RuntimeError so
  # existing `rescue RuntimeError` callers keep working.
  class Error < RuntimeError; end

  @cache = {}

  # ---------------------------------------------------------------- public API

  # Words: a String (one utterance) or Array of words.
  # Returns a String (or Array of Strings, matching the input shape).
  #
  # Options:
  #   language:        espeak voice, default "en-us"
  #   phone_sep:       inserted between phones, default "" (mɑ̃ʒe)
  #   word_sep:        joins multiword utterances,  default " "
  #   strip_stress:    remove ˈ ˌ from output,     default true
  #   language_switch: :remove (default) or :keep
  #   workers:         espeak-ng calls in flight, default DEFAULT_WORKERS
  def phonemize(words, language: DEFAULT_LANGUAGE, phone_sep: '',
                word_sep: ' ', strip_stress: true, language_switch: :remove,
                workers: DEFAULT_WORKERS)
    if words.is_a?(Array)
      phonemize_batch(words, language:, phone_sep:, word_sep:,
                             strip_stress:, language_switch:, workers:)
    else
      phonemize_batch([words], language:, phone_sep:, word_sep:,
                               strip_stress:, language_switch:, workers:).first
    end
  end

  # Clears the word -> phonemization cache. Useful between unrelated
  # batches (to free memory) or after an espeak-ng upgrade (stale entries).
  def clear_cache
    @cache = {}
  end

  # ---------------------------------------------------------------- backend call

  # One espeak-ng call. Returns the raw output string (may span several
  # words or lines; the caller interprets it).
  #
  # With a non-empty +phone_sep+, espeak-ng is called with a bare --sep:
  # phones come back separated by single spaces and words by double spaces.
  # The requested separator itself is never handed to espeak-ng (it would
  # replace the phone spaces but leave single-space word boundaries, making
  # the two indistinguishable); #stitch inserts it instead, which also allows
  # multi-character separators.
  def espeak_raw(text, language, phone_sep: nil)
    args = ['espeak-ng', '-q', '--ipa', '-v', language]
    args << '--sep' unless phone_sep.to_s.empty?
    args << '--stdin'

    # NB: text + "\n", not text << "\n" — << would mutate the caller's
    # string, and pieces are hash keys in transcribe_all's ipa_map
    out, err, status = begin
      Open3.capture3(*args, stdin_data: "#{text}\n")
    rescue Errno::ENOENT
      raise Error, 'espeak-ng not found on PATH ' \
                   '(apt install espeak-ng / brew install espeak-ng)'
    end

    raise Error, "espeak-ng failed (#{status.exitstatus}): #{err.strip}" unless status.success?

    warn "WARNING: espeak-ng returned no output for: #{text[0, 40].inspect}" \
      if out.strip.empty? && !text.strip.empty?

    out
  end

  # ---------------------------------------------------------------- pipeline

  # Phonemizes a whole batch of words, fanning the espeak-ng calls out over
  # +workers+ parallel processes. This is the fast path for large lexicons:
  # prefer it over calling #phonemize in a loop (one fork+exec per word).
  #
  # @param words [Array<String>] the words (or short utterances) to phonemize
  # @param language [String] espeak-ng voice, e.g. "fr" (default "en-us")
  # @param phone_sep [String] inserted between phonemes, default ""
  # @param word_sep [String] joins multiword utterances, default " "
  # @param strip_stress [Boolean] remove espeak-ng stress marks (ˈ ˌ)
  # @param language_switch [Symbol] :remove (default) or :keep language tags
  # @param workers [Integer] espeak-ng processes kept in flight
  # @return [Array<String>] one phonemization per input word, in order
  def phonemize_batch(words, language:, phone_sep:, word_sep:,
                      strip_stress:, language_switch:, workers: DEFAULT_WORKERS)
    check_workers!(workers)
    # Guard for nil: only copy when some element isn't already a String
    words = words.map(&:to_s) unless words.all? { |w| w.is_a?(String) }
    # Cache: word forms repeat constantly across a lexicon. Options are
    # fixed for the whole call, so the key is a pure function of the word —
    # memoize it to build each key array only once per unique word.
    key_of = Hash.new do |h, w|
      h[w] = [w, language, phone_sep, word_sep, strip_stress, language_switch]
    end
    todo = words.uniq.reject { |w| @cache.key?(key_of[w]) }

    unless todo.empty?
      # Punctuation handling: split utterances on punctuation, transcribe
      # only the clean chunks, splice punctuation back by position
      chunks = todo.map { |w| split_punctuation(w) }

      # Pieces are sent stripped: the whitespace around a piece (e.g. the
      # space in "hello, world") is restored as word_sep by #stitch.
      clean_words = chunks.flatten.reject { |p| PUNCT.match?(p) }
                          .map(&:strip).reject(&:empty?).uniq
      ipa_map = transcribe_all(clean_words, language, phone_sep, workers:)

      todo.each_with_index do |w, i|
        @cache[key_of[w]] = stitch(chunks[i], ipa_map,
                                   phone_sep:, word_sep:, strip_stress:,
                                   language_switch:)
      end
    end

    words.map { |w| @cache[key_of[w]] }
  end

  def check_workers!(workers)
    return if workers.is_a?(Integer) && workers.positive?

    raise ArgumentError, "workers must be a positive Integer (got #{workers.inspect})"
  end

  # One espeak-ng call per piece (per-line isolation), drained by a
  # machine-dependent pool of worker threads.
  def transcribe_all(pieces, language, phone_sep, workers: DEFAULT_WORKERS)
    queue = Queue.new
    workers = [workers, pieces.size].min
    pieces.each { |p| queue << p }
    workers.times { queue << nil } # poison pills: one per worker

    results = Array.new(workers) { {} }
    threads = Array.new(workers) do |i|
      Thread.new do
        while (piece = queue.pop)
          results[i][piece] = espeak_raw(piece, language, phone_sep:).strip
        end
      end
    end
    threads.each(&:join)

    results.each_with_object({}) { |h, map| map.merge!(h) }
  end

  # utterance -> [punct, word, punct, word, ...]
  def split_punctuation(word)
    word.split(PUNCT).reject(&:empty?)
  end

  # Reassemble one utterance: punctuation back in place, separators applied.
  # ipa_map maps each (stripped) chunk piece to its raw IPA. Whitespace
  # around a piece — a word boundary next to punctuation — becomes word_sep.
  def stitch(parts, ipa_map, phone_sep:, word_sep:, strip_stress:,
             language_switch:)
    parts.map do |part|
      next part if PUNCT.match?(part) # punctuation: verbatim

      core = part.strip
      next word_sep if core.empty? # whitespace between two punctuation runs

      lead  = part.match?(/\A\s/) ? word_sep : ''
      trail = part.match?(/\s\z/) ? word_sep : ''
      lead + format_ipa(ipa_map[core] || '', phone_sep:, word_sep:,
                                             strip_stress:, language_switch:) + trail
    end.join
  end

  # Raw espeak-ng output for one piece -> final string.
  #
  # Contiguous mode (phone_sep ""): words are separated by whitespace.
  # Separator mode: espeak-ng was called with a bare --sep, so phones are
  # separated by one space and words by two or more (see #espeak_raw).
  # Working on tokens rather than substituting characters keeps a removed
  # tag or stress mark from leaving an empty phone or a spurious boundary.
  # With strip_stress, the "-" espeak-ng emits as a liaison marker (e.g.
  # "les amis" -> "le-z ami") is dropped in both modes: a user-chosen "-"
  # phone separator is only inserted afterwards, so it always survives.
  def format_ipa(raw, phone_sep:, word_sep:, strip_stress:, language_switch:)
    raw = raw.gsub(LANG_SWITCH, '') if language_switch == :remove
    clean = ->(tok) { strip_stress ? tok.delete('ˈˌ-') : tok }

    if phone_sep.empty?
      raw.split.map(&clean).reject(&:empty?).join(word_sep)
    else
      raw.strip.split(/\s{2,}|\n/).filter_map do |word|
        phones = word.split.map(&clean).reject(&:empty?)
        phones.join(phone_sep) unless phones.empty?
      end.join(word_sep)
    end
  end
end
