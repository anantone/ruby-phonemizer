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

    it 'strips stress marks by default' do
      result = Phonemizer.phonemize('tableau', language: 'fr-fr')
      expect(result).not_to include('ˈ')
      expect(result).not_to include('ˌ')
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
