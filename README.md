phonemizer
============

[![Gem Version](https://img.shields.io/gem/v/phonemizer.svg)](https://rubygems.org/gems/phonemizer)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A minimal Ruby wrapper around espeak-ng for simple word-to-IPA phonemization, with caching and parallelism.


Requirements
----------------------------------------------------------------

- Ruby 3.0+
- **espeak-ng** command-line tool must be installed:
  ```bash
  apt install espeak-ng     # Debian/Ubuntu
  brew install espeak-ng    # macOS
  ```


Installation
----------------------------------------------------------------

Add to your Gemfile:

```ruby
gem "phonemizer"
```

Or install directly:

```bash
gem install phonemizer
```


Usage
----------------------------------------------------------------

```ruby
require "phonemizer"

# Single word
Phonemizer.phonemize("manger", language: "fr-fr")
# => "mɑ̃ʒe"

# Batch - pass an Array, get an Array back (same order)
Phonemizer.phonemize(["docteur", "tableau", "pastille"], language: "fr-fr")
# => ["dɔktœʁ", "tablo", "pastij"]
```


Options
----------------------------------------------------------------

```ruby
Phonemizer.phonemize(
  "les amis",
  language:        "fr-fr",    # espeak voice (default "en-us")
  phone_sep:       "",         # separator between phones ("" = contiguous)
  word_sep:        " ",        # separator between words in one utterance
  strip_stress:    true,       # remove stress marks and liaison hyphens
  language_switch: :remove     # :remove or :keep, for inline (fr)/(en) tags
)
```

Separate each phone explicitly:

```ruby
Phonemizer.phonemize("tableau", language: "fr-fr", phone_sep: " ")
# => "t a b l o"
```

Keep the language-switch markers espeak emits mid-utterance:

```ruby
Phonemizer.phonemize("le wifi", language: "fr-fr", language_switch: :keep)
# => "lə (fr) wifi"
```


Punctuation
----------------------------------------------------------------

Punctuation is preserved verbatim and never sent to espeak, so whole sentences pass through cleanly:

```ruby
Phonemizer.phonemize("Bonjour, comment ça va ?", language: "fr-fr")
# => "bɔ̃ʒuʁ, kɔmɑ̃ sa va ?"
```

Apostrophes are kept inside the word on purpose, so elisions stay intact and liaison consonants aren't lost:

```ruby
Phonemizer.phonemize("aujourd'hui", language: "fr-fr")
# => "oʒuʁdɥi"
```


Caching
----------------------------------------------------------------

Results are cached per `(word, language, options)`. Useful when the same forms recur across a large lexicon. Call `clear_cache` to free memory or start fresh:

```ruby
Phonemizer.clear_cache
```


Thread Safety
----------------------------------------------------------------

This gem is **not thread-safe**. The internal cache uses a plain Hash without synchronization. If you call `phonemize` from multiple threads:

- Duplicate espeak-ng calls may occur for the same word
- Cache reads may see stale state

**Workaround:** Wrap your calls in your own `Mutex`:

```ruby
@mutex = Mutex.new
@mutex.synchronize { Phonemizer.phonemize(words, language: "fr-fr") }
```


API Reference
----------------------------------------------------------------

### `Phonemizer.phonemize(words, **options)`

Phonemize text to IPA. Returns a String for String input, Array for Array input.

**Arguments:**
- `words` — String or Array of Strings
- `language` — espeak voice (default: `"en-us"`)
- `phone_sep` — separator between phones (default: `""`)
- `word_sep` — separator between words in multi-word input (default: `" "`)
- `strip_stress` — remove stress marks ˈ ˌ and liaison hyphens (default: `true`)
- `language_switch` — `:remove` or `:keep` for inline language tags (default: `:remove`)

### `Phonemizer.espeak_raw(text, language, phone_sep: nil)`

Low-level: call espeak-ng directly. Returns raw IPA output string.

**Arguments:**
- `text` — text to phonemize
- `language` — espeak voice
- `phone_sep` — optional separator (passed as `--sep` to espeak-ng)

### `Phonemizer.clear_cache`

Clear the internal phonemization cache. Returns the new empty cache Hash.


Reading from a File
----------------------------------------------------------------

`phonemize` accepts any Array of Strings, so a wordlist is a one-liner:

```ruby
lines = File.readlines("words.txt", chomp: true).reject(&:empty?)
File.write("words.ipa", Phonemizer.phonemize(lines, language: "fr-fr").join("\n"))
```


Contributing
----------------------------------------------------------------

Bug reports and pull requests are welcome on [GitHub](https://github.com/anantone/ruby-phonemizer).


License
----------------------------------------------------------------

MIT
