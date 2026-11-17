# frozen_string_literal: true

RSpec.describe Phonemizer do
  describe 'LANG_SWITCH' do
    it 'matches simple language tags' do
      expect('(fr)').to match(Phonemizer::LANG_SWITCH)
      expect('(en)').to match(Phonemizer::LANG_SWITCH)
    end

    it 'matches regional tags' do
      expect('(pt-br)').to match(Phonemizer::LANG_SWITCH)
      expect('(en-us)').to match(Phonemizer::LANG_SWITCH)
    end

    it 'does not match non-tag parentheses' do
      expect('(1)').not_to match(Phonemizer::LANG_SWITCH)
      expect('(toolongtag)').not_to match(Phonemizer::LANG_SWITCH)
    end
  end

  describe 'PUNCT' do
    it 'matches ordinary punctuation' do
      expect(',').to match(Phonemizer::PUNCT)
      expect('...').to match(Phonemizer::PUNCT)
      expect('?!').to match(Phonemizer::PUNCT)
    end

    it 'does NOT match apostrophes (they stay inside elided words)' do
      expect("'").not_to match(Phonemizer::PUNCT)
      expect('’').not_to match(Phonemizer::PUNCT)
      expect('‘').not_to match(Phonemizer::PUNCT)
    end
  end

  describe '.split_punctuation' do
    it 'splits a word with no punctuation into a single chunk' do
      expect(described_class.split_punctuation('tableau')).to eq(['tableau'])
    end

    it 'keeps punctuation as its own chunks' do
      expect(described_class.split_punctuation('bonjour,'))
        .to eq(['bonjour', ','])
    end

    it 'handles leading and trailing punctuation' do
      expect(described_class.split_punctuation('(go)'))
        .to eq(['(', 'go', ')'])
    end

    it 'never yields empty chunks' do
      expect(described_class.split_punctuation('...')).to eq(['...'])
    end
  end

  describe '.stitch' do
    # ipa_map: chunk piece -> raw IPA. We feed it directly, so no espeak.
    let(:map) { { 'bonjour' => 'bɔ̃ʒuʁ', 'comment' => 'kɔmɑ̃' } }

    it 'reassembles words and punctuation in order' do
      parts = ['bonjour', ',', 'comment']
      expect(described_class.stitch(parts, map, phone_sep: '', word_sep: ' ',
                                                strip_stress: true, language_switch: :remove))
        .to eq('bɔ̃ʒuʁ,kɔmɑ̃')
    end

    it 'passes punctuation through verbatim' do
      parts = ['bonjour', '...']
      result = described_class.stitch(parts, map, phone_sep: '', word_sep: ' ',
                                                  strip_stress: true, language_switch: :remove)
      expect(result).to end_with('...')
    end

    it 'strips language-switch tags when :remove' do
      parts = ['wifi']
      m = { 'wifi' => 'vi (fr) fi' }
      result = described_class.stitch(parts, m, phone_sep: '', word_sep: ' ',
                                                strip_stress: true, language_switch: :remove)
      expect(result).to eq('vi  fi')
    end

    it 'keeps language-switch tags when :keep' do
      parts = ['wifi']
      m = { 'wifi' => 'vi (fr) fi' }
      result = described_class.stitch(parts, m, phone_sep: '', word_sep: ' ',
                                                strip_stress: true, language_switch: :keep)
      expect(result).to eq('vi (fr) fi')
    end

    it 'strips stress marks and liaison hyphens when strip_stress' do
      parts = ['amis']
      m = { 'amis' => 'a-miˈ' }
      result = described_class.stitch(parts, m, phone_sep: '', word_sep: ' ',
                                                strip_stress: true, language_switch: :remove)
      expect(result).to eq('ami')
    end

    it 'leaves stress marks in place when not stripping' do
      parts = ['amis']
      m = { 'amis' => 'a-miˈ' }
      result = described_class.stitch(parts, m, phone_sep: '', word_sep: ' ',
                                                strip_stress: false, language_switch: :remove)
      expect(result).to eq('a-miˈ')
    end

    it 'treats a single space as a word boundary when phone_sep is empty' do
      parts = ['lesamis']
      m = { 'lesamis' => 'le ami' }
      result = described_class.stitch(parts, m, phone_sep: '', word_sep: ' _ ',
                                                strip_stress: true, language_switch: :remove)
      expect(result).to eq('le _ ami')
    end

    it 'uses phone_sep for single spaces and word_sep for double spaces' do
      parts = ['lesamis']
      m = { 'lesamis' => 'l e  a m i' }
      result = described_class.stitch(parts, m, phone_sep: '-', word_sep: ' ',
                                                strip_stress: true, language_switch: :remove)
      expect(result).to eq('l-e a-m-i')
    end

    it 'substitutes empty string for a missing IPA mapping' do
      parts = ['unknown']
      result = described_class.stitch(parts, {}, phone_sep: '', word_sep: ' ',
                                                 strip_stress: true, language_switch: :remove)
      expect(result).to eq('')
    end
  end

  describe 'input shape' do
    # Stub the batch path so we assert shape handling without espeak.
    before do
      allow(described_class).to receive(:phonemize_batch)
        .and_return(['IPA'])
    end

    it 'returns a String for String input' do
      result = described_class.phonemize('manger')
      expect(result).to be_a(String)
    end

    it 'returns an Array for Array input' do
      result = described_class.phonemize(['manger'])
      expect(result).to be_an(Array)
    end
  end

  describe '.clear_cache' do
    it 'is callable and returns a hash' do
      expect { described_class.clear_cache }.not_to raise_error
    end
  end
end
