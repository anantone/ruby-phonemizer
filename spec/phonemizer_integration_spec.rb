# frozen_string_literal: true

RSpec.describe 'Phonemizer integration', skip: !espeak_available? &&
                                               'espeak-ng not installed on PATH' do
  describe '.espeak_raw' do
    it 'returns non-empty IPA for a known word' do
      out = Phonemizer.espeak_raw('manger', 'fr-fr')
      expect(out.strip).not_to be_empty
    end

    it 'raises when espeak-ng is given a bogus voice' do
      # A nonexistent voice makes espeak-ng exit non-zero.
      expect do
        Phonemizer.espeak_raw('test', 'xx-xx')
      end.to raise_error(/espeak-ng failed/)
    end
  end

  describe '.phonemize' do
    it 'phonemizes a single French word' do
      result = Phonemizer.phonemize('manger', language: 'fr-fr')
      expect(result).to be_a(String)
      expect(result).not_to include(' ') # single word, no word boundary
    end

    it 'preserves input order and length for a batch' do
      words = %w[docteur tableau pastille]
      batch = Phonemizer.phonemize(words, language: 'fr-fr')

      expect(batch).to be_an(Array)
      expect(batch.length).to eq(words.length)

      # Each batched element must match the standalone phonemization of the
      # word at the same index — this is what actually pins the order.
      batch.each_with_index do |ipa, i|
        expect(ipa).to eq(Phonemizer.phonemize(words[i], language: 'fr-fr'))
      end
    end

    it 'preserves punctuation verbatim' do
      result = Phonemizer.phonemize('bonjour, salut', language: 'fr-fr')
      expect(result).to include(',')
    end

    it 'keeps apostrophes inside the word (no split, liaison preserved)' do
      result = Phonemizer.phonemize("aujourd'hui", language: 'fr-fr')
      # one continuous phonemized token, no space where the apostrophe was
      expect(result).not_to include(' ')
    end

    it 'performs the liaison in a multi-word utterance (les amis)' do
      # espeak-ng emits "le-z amˈi": the final s of "les" is pronounced [z]
      # before the vowel of "amis". The liaison consonant must survive;
      # only the "-" marker (and stress) may be stripped.
      result = Phonemizer.phonemize('les amis', language: 'fr-fr')
      expect(result).to include('z')     # liaison consonant pronounced
      expect(result).not_to include('-') # liaison hyphen stripped (contiguous mode)
    end

    it 'does not liaison across separate batch elements (per-word isolation)' do
      # Each array element is its own espeak-ng call, so "les" alone has no
      # following vowel and its final s stays silent: no liaison by design.
      batch = Phonemizer.phonemize(%w[les amis], language: 'fr-fr')
      expect(batch.length).to eq(2)
      expect(batch.join).not_to include('z')
    end

    it 'inserts phone_sep between phones when requested' do
      result = Phonemizer.phonemize('tableau', language: 'fr-fr',
                                               phone_sep: '.')
      expect(result).to include('.')
      expect(result).not_to include(' ')
    end

    it "keeps a '-' separator when strip_stress is off" do
      result = Phonemizer.phonemize('tableau', language: 'fr-fr',
                                               phone_sep: '-',
                                               strip_stress: false)
      expect(result).to include('-')
    end

    it 'keeps word boundaries and drops the liaison marker with phone_sep' do
      result = Phonemizer.phonemize('les amis', language: 'fr-fr', phone_sep: '|')
      expect(result).to eq('l|e|z a|m|i') # espeak-ng attaches the liaison z to "les"
    end

    it 'keeps the space after punctuation (hello, world)' do
      result = Phonemizer.phonemize('hello, world')
      expect(result).to match(/\A\S+, \S+\z/)
    end

    it 'strips stress marks by default' do
      result = Phonemizer.phonemize('tableau', language: 'fr-fr')
      expect(result).not_to include('ˈ')
      expect(result).not_to include('ˌ')
    end
  end

  describe 'bin/phonemize' do
    let(:bin) { File.expand_path('../bin/phonemize', __dir__) }
    let(:lib) { File.expand_path('../lib', __dir__) }

    it 'starts with a shebang so it runs directly' do
      expect(File.readlines(bin).first).to start_with('#!')
    end

    it 'reads lines from stdin when given no argument' do
      out, status = Open3.capture2('ruby', "-I#{lib}", bin, '-l', 'fr-fr',
                                   stdin_data: "les\namis\n")
      expect(status).to be_success
      expect(out.lines.size).to eq(2)
    end

    it 'exits non-zero on -j 0' do
      _, err, status = Open3.capture3('ruby', "-I#{lib}", bin, '-j', '0', 'hello')
      expect(status).not_to be_success
      expect(err).to include('workers')
    end
  end

  describe 'caching' do
    it 'returns identical output on repeated calls' do
      first  = Phonemizer.phonemize('manger', language: 'fr-fr')
      second = Phonemizer.phonemize('manger', language: 'fr-fr')
      expect(second).to eq(first)
    end

    it 'recomputes correctly after clear_cache' do
      before = Phonemizer.phonemize('manger', language: 'fr-fr')
      Phonemizer.clear_cache
      after = Phonemizer.phonemize('manger', language: 'fr-fr')
      expect(after).to eq(before)
    end
  end
end
