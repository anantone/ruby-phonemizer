phonemizer
============

[![Gem Version](https://img.shields.io/gem/v/phonemizer.svg)](https://rubygems.org/gems/phonemizer)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-rubydoc.info-blue.svg)](https://rubydoc.info/gems/phonemizer)

A minimal Ruby wrapper around [espeak-ng](https://github.com/espeak-ng/espeak-ng) for simple word-to-IPA phonemization, with caching and parallelism. Supports [these languages](https://github.com/espeak-ng/espeak-ng/blob/master/docs/languages.md).

> **Phonemizing a large batch?** Each word here costs one fork+exec of the `espeak-ng` CLI. For big lexicons, see [`phonemizer_ffi`](https://rubygems.org/gems/phonemizer_ffi) — a drop-in replacement with the same `Phonemizer.phonemize` API that calls `libespeak-ng` in-process via FFI instead (no process spawned per word), typically ~40x faster on batches, with the same output.


Requirements
----------------------------------------------------------------

- Ruby 3.1+
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
  language_switch: :remove,    # :remove or :keep, for inline (fr)/(en) tags
  workers:         DEFAULT_WORKERS  # parallel espeak-ng calls (default: CPUs - 1)
)
```

Separate each phone explicitly:

```ruby
Phonemizer.phonemize("tableau", language: "fr-fr", phone_sep: " ")
# => "t a b l o"
```

Keep the language-switch markers espeak emits mid-utterance:

```ruby
Phonemizer.phonemize("le célèbre Schwarzenegger", language: "fr-fr", language_switch: :keep)
"lə selɛbʁ (en)ʃwɔːzənɛɡə(fr)"
```


Command line
----------------------------------------------------------------

The `phonemize` executable exposes the same options as flags. Pass text as arguments, or a file path to phonemize it line by line:

```bash
phonemize "hello world"
phonemize -l fr-fr "les amis"
phonemize -l fr-fr words.txt > words.ipa
```

```bash
phonemize --help
# Usage: phonemize [options] [text | file]
#     -l, --language LANG           espeak voice (default: en-us)
#     -p, --phone-sep SEP           separator between phones (default: none)
#     -w, --word-sep SEP            separator between words (default: space)
#     -s, --[no-]strip-stress       strip stress marks and liaison hyphens (default: yes)
#     -k, --keep-language-switch    keep inline (en)/(fr) language tags (default: remove)
#     -j, --workers N               parallel espeak-ng calls (default: CPUs - 1)
#     -h, --help                    show this help
```

```bash
phonemize -l fr-fr -p " " tableau
# => t a b l o
```


Punctuation
----------------------------------------------------------------

Punctuation is preserved verbatim and never sent to espeak, so whole sentences pass through cleanly:

```ruby
Phonemizer.phonemize("Bonjour, comment ça va ?", language: "fr-fr")
# => "bɔ̃ʒuʁ,kɔmɑ̃ sa va?"
```

Apostrophes are kept inside the word on purpose, so elisions stay intact and liaison consonants aren't lost:

```ruby
Phonemizer.phonemize("aujourd'hui", language: "fr-fr")
# => "oʒuʁdyi"
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
- `workers` — max parallel espeak-ng calls (default: `Phonemizer::DEFAULT_WORKERS`, CPU count - 1, min 1)

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

On the command line, just pass a file path — the executable phonemizes it line by line (see [Command line](#command-line)):

```bash
phonemize -l fr-fr words.txt > words.ipa
```

In Ruby, `phonemize` accepts any Array of Strings and returns an Array in the same order, so a wordlist is a one-liner when you want the result in memory:

```ruby
lines = File.readlines("words.txt", chomp: true).reject(&:empty?)
ipa = Phonemizer.phonemize(lines, language: "fr-fr") # Array of IPA strings, same order
```


Contributing
----------------------------------------------------------------

Bug reports and pull requests are welcome on [GitHub](https://github.com/anantone/ruby-phonemizer).


License
----------------------------------------------------------------

MIT
