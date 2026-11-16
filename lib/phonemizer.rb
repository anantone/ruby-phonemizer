# frozen_string_literal: true

require_relative "phonemizer/version"
require "open3"
require "etc"

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

  DEFAULT_LANGUAGE = "en-us"
  DEFAULT_WORKERS  = [Etc.nprocessors - 1, 1].max

  # espeak emits parenthesized language tags on language switches, e.g.
  # (en) / (fr) / (pt-br); the pattern covers any tag espeak may emit.
  LANG_SWITCH = /\((?:[a-z]{2,3}(?:-[a-z0-9]+)*)\)/

  # Characters espeak would try to pronounce; we split them out instead.
  # Apostrophes are EXCLUDED on purpose: they must stay inside the word
  # they elide (aujourd'hui, l'instar). Splitting on them transcribes the
  # halves separately and drops liaison consonants (oʒuʁdɥi -> oʒuʁ + yi).
  PUNCT = /([[:punct:]&&[^'’‘]]+)/

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
  def phonemize(words, language: DEFAULT_LANGUAGE, phone_sep: "",
                word_sep: " ", strip_stress: true, language_switch: :remove)
    if words.is_a?(Array)
      phonemize_batch(words, language:, phone_sep:, word_sep:,
                      strip_stress:, language_switch:)
    else
      phonemize_batch([words], language:, phone_sep:, word_sep:,
                      strip_stress:, language_switch:).first
    end
  end

  def clear_cache
    @cache = {}
  end

  # ---------------------------------------------------------------- backend call

  # One espeak-ng call. Returns the raw output string (may span several
  # words or lines; the caller interprets it).
  def espeak_raw(text, language, phone_sep: nil)
    args = ["espeak-ng", "-q", "--ipa", "-v", language]
    # --sep only when explicitly requested: some espeak-ng builds reject it,
    # and the default contiguous IPA output needs no separator anyway.
    args << "--sep=#{phone_sep}" if phone_sep && !phone_sep.empty?
    args << "--stdin"

    # NB: text + "\n", not text << "\n" — << would mutate the caller's
    # string, and pieces are hash keys in transcribe_all's ipa_map
    out, err, status = Open3.capture3(*args, stdin_data: text + "\n")

    raise "espeak-ng failed (#{status.exitstatus}): #{err.strip}" unless status.success?

    warn "WARNING: espeak-ng returned no output for: #{text[0, 40].inspect}" \
      if out.strip.empty? && !text.strip.empty?

    out
  end

  # ---------------------------------------------------------------- pipeline

  def phonemize_batch(words, language:, phone_sep:, word_sep:,
                      strip_stress:, language_switch:)
    # Guard for nil
    words = words.map { |w| w.to_s }  # Convert nil to empty string
    # Cache: word forms repeat constantly across a lexicon
    key = ->(w) { [w, language, phone_sep, word_sep, strip_stress] }
    todo = words.reject { |w| @cache.key?(key.call(w)) }.uniq

    unless todo.empty?
      # Punctuation handling: split utterances on punctuation, transcribe
      # only the clean chunks, splice punctuation back by position
      chunks = todo.map { |w| split_punctuation(w) }

      clean_words = chunks.flatten.reject { |p| p =~ PUNCT }.uniq
      ipa_map = transcribe_all(clean_words, language, phone_sep)

      todo.each_with_index do |w, i|
        @cache[key.call(w)] = stitch(chunks[i], ipa_map,
                                     phone_sep:, word_sep:, strip_stress:,
                                     language_switch:)
      end
    end

    words.map { |w| @cache[key.call(w)] }
  end

  # One espeak-ng call per piece (per-line isolation), drained by a
  # machine-dependent pool of worker threads.
  def transcribe_all(pieces, language, phone_sep, workers: DEFAULT_WORKERS)
    queue = Queue.new
    pieces.each { |p| queue << p }
    workers.times { queue << nil }        # poison pills: one per worker

    results = Array.new(workers) { [] }
    threads = Array.new(workers) do |i|
      Thread.new do
        while (piece = queue.pop)
          results[i] << [piece, espeak_raw(piece, language, phone_sep:).strip]
        end
      end
    end
    threads.each(&:join)

    results.each_with_object({}) { |pairs, map| map.merge!(pairs.to_h) }
  end

  # utterance -> [punct, word, punct, word, ...]
  def split_punctuation(word)
    word.split(PUNCT).reject(&:empty?)
  end

  # Reassemble one utterance: punctuation back in place, separators applied.
  # ipa_map maps each chunk piece to its raw IPA (looked up by content).
  def stitch(parts, ipa_map, phone_sep:, word_sep:, strip_stress:,
             language_switch:)
    parts.map do |part|
      next part if part =~ PUNCT                     # punctuation: verbatim
      t = ipa_map[part] || ""
      t = t.gsub(LANG_SWITCH, "") if language_switch == :remove
      # Strip stress marks always; strip the liaison hyphen only in contiguous
      # mode, where espeak emits it (e.g. "les amis" -> "le-z ami"). In --sep
      # mode a "-" is a user-chosen phone separator, never a liaison marker,
      # so it must survive.
      if strip_stress
        t = t.delete("ˈˌ")
        t = t.delete("-") if phone_sep.empty?
      end
      if phone_sep.empty?
        # contiguous phones: a plain space is a word boundary
        t = t.gsub(" ", word_sep)
      else
        # --sep was requested: single spaces are phone separators, double
        # spaces are word boundaries. Protect the boundaries first, otherwise
        # the single-space substitution consumes one half of every double
        # space and the word boundary is lost.
        t = t.gsub("  ", "\x00").gsub(" ", phone_sep).gsub("\x00", word_sep)
      end
      t
    end.join
  end
end