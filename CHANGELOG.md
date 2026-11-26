# Changelog

## Unreleased

- Fix `phone_sep:`: espeak-ng is now called with a bare `--sep` and the separator is inserted by `stitch`. Passing `--sep=<char>` made espeak-ng use that char between phones but a single space between words, so word boundaries were lost (`"l-e--z-a-m-i"` for `les amis`) and language-tag removal left empty phones (`"l-ə---w-aɪ-f-aɪ-"`). Multi-character separators now work. With `strip_stress`, the espeak liaison `-` is dropped in separator mode too; a user-chosen `-` separator is unaffected
- Fix lost word boundaries next to punctuation: `"hello, world"` now gives `"həloʊ, wɜːld"` (was `"həloʊ,wɜːld"`); whitespace around punctuation becomes `word_sep`
- Removing a language tag no longer leaves a doubled separator (`"vi fi"`, was `"vi  fi"`)
- `workers:` must be a positive Integer; `0` used to return empty strings silently, now raises `ArgumentError`
- New `Phonemizer::Error` (subclass of `RuntimeError`) for espeak-ng failures; a missing espeak-ng binary raises it with an install hint instead of a raw `Errno::ENOENT`
- `phonemize` executable: shebang moved to line 1 (it was after the magic comment, so `./bin/phonemize` didn't run and `gem build` warned); reads lines from stdin when given no argument (prints usage if stdin is a terminal); a file is only detected when it is the single argument; invalid options and errors print to stderr and exit 1

## 0.5.2 - 2026-11-24

- rubocop : `.rubocop.yml` ajouté (TargetRubyVersion 3.1, NewCops désactivés, quotes simples, plafonds Metrics relevés à l'état actuel, BlockLength hors spec/) ; autocorrections appliquées ; 0 offense, specs inchangés

## 0.5.1 - 2026-11-24

- RDoc: document the remaining public methods (`clear_cache`, `phonemize_batch` with `@param`/`@return`); add an `rdoc` task to the Rakefile (`rake rdoc` generates the HTML docs, README as home page) and `rdoc` as a development dependency
- YARD support for rubydoc.info: `.yardopts` file (markdown markup, README as front page), `rake yard` task in the Rakefile (aliased as `rake doc`, generates `doc/`); `yard` and `kramdown` added as development dependencies; gemspec metadata (`source_code_uri`, `changelog_uri`, `bug_tracker_uri`, `documentation_uri`) pointing at the GitHub repo and `https://rubydoc.info/gems/phonemizer`; documentation link added to the README. Documentation-only change

## 0.5.0 - 2026-11-18

- Add option flags to the `phonemize` executable — `-l/--language`, `-p/--phone-sep`, `-w/--word-sep`, `-s/--[no-]strip-stress`, `-k/--keep-language-switch`, `-j/--workers`, `-h/--help` — forwarded as keyword options to `Phonemizer.phonemize`; document command-line usage in README
- Bump version to 0.5.0

## 0.4.1 - 2026-11-18

- Add file handling to the `phonemize` executable: a file path argument is phonemized line by line (747f019 "Add file handling for phonemization input")
- Bump version to 0.4.1

## 0.4.0 - 2026-11-17

- Fix `phonemize` executable: `require "phonemizer"` and call `Phonemizer.phonemize` so the bin actually loads (fef5376 "Fix executable")
- Bump version to 0.4.0

## 0.3.0 - 2026-11-17

- Add `phonemize` executable (`bin/phonemize`), registered via `spec.executables` in the gemspec (46e6b24 "Add executable")
- Bump version to 0.3.0

## 0.2.0 - 2026-11-17

- Bump version to 0.2.0 (e44dbf1)
- Add `workers:` option to `Phonemizer.phonemize` to cap parallel espeak-ng calls (default `DEFAULT_WORKERS`, CPU count - 1); memoize cache keys and skip copying the input array when it already holds strings (e44dbf1 "Small improvements")
- Rubocop cleanup across lib, specs, Rakefile and gemspec; README links to the espeak-ng supported languages list (1c4d814 "Rubocop and supported languages")
- Document Ruby 3.1+ requirement in README (1632080 "Small improvements")

## 0.1.0 - 2026-11-15

Initial release.
