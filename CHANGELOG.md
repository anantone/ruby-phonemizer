# Changelog

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
