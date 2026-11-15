
 phonemizer
============

A minimal Ruby wrapper around espeak-ng for simple word-to-IPA
phonemization, with caching and parallelism.

Requires the espeak-ng command-line tool, installed separately:

    apt install espeak-ng     # Debian/Ubuntu
    brew install espeak-ng    # macOS


INSTALLATION
----------------------------------------------------------------

Add to your Gemfile:

    gem "phonemizer"


USAGE
----------------------------------------------------------------

    require "phonemizer"

    # Single word
    Phonemizer.phonemize("manger", language: "fr-fr")
    # => "mɑ̃ʒe"

    # Batch - pass an Array, get an Array back (same order)
    Phonemizer.phonemize(["docteur", "tableau", "pastille"], language: "fr-fr")
    # => ["dɔktœʁ", "tablo", "pastij"]


OPTIONS
----------------------------------------------------------------

    Phonemizer.phonemize(
      "les amis",
      language:        "fr-fr",  # espeak voice (default "en-us")
      phone_sep:       "",       # separator between phones ("" = contiguous)
      word_sep:        " ",      # separator between words in one utterance
      strip_stress:    true,     # remove stress marks and liaison hyphens
      language_switch: :remove   # :remove or :keep, for inline (fr)/(en) tags
    )

Separate each phone explicitly:

    Phonemizer.phonemize("tableau", language: "fr-fr", phone_sep: " ")
    # => "t a b l o"

Keep the language-switch markers espeak emits mid-utterance:

    Phonemizer.phonemize("le wifi", language: "fr-fr", language_switch: :keep)
    # => "lə (fr) wifi"


PUNCTUATION
----------------------------------------------------------------

Punctuation is preserved verbatim and never sent to espeak, so whole
sentences pass through cleanly:

    Phonemizer.phonemize("Bonjour, comment ça va ?", language: "fr-fr")
    # => "bɔ̃ʒuʁ, kɔmɑ̃ sa va ?"

Apostrophes are kept inside the word on purpose, so elisions stay intact
and liaison consonants aren't lost:

    Phonemizer.phonemize("aujourd'hui", language: "fr-fr")
    # => "oʒuʁdɥi"


CACHING
----------------------------------------------------------------

Results are cached per (word, language, options). Useful when the same
forms recur across a large lexicon. Call clear_cache to free memory or
start fresh:

    Phonemizer.clear_cache


READING FROM A FILE
----------------------------------------------------------------

phonemize accepts any Array of Strings, so a wordlist is a one-liner:

    lines = File.readlines("words.txt", chomp: true).reject(&:empty?)
    File.write("words.ipa", Phonemizer.phonemize(lines, language: "fr-fr").join("\n"))


LICENSE
----------------------------------------------------------------

MIT
