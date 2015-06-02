require 'spec_helper'

require 'geocode_records/smarty_streets'

describe GeocodeRecords::SmartyStreets do

  describe '.bin_path' do
    subject { described_class.bin_path }

    it { is_expected.to eq 'node_modules/.bin/smartystreets' }
  end

  describe '.compatible?' do
    before { allow(described_class).to receive(:run).and_return("#{version}\n") }

    subject { described_class.compatible? }

    context 'v1.3.1' do
      let(:version) { '1.3.1' }

      it { is_expected.to be false }
    end

    context 'v1.3.2' do
      let(:version) { '1.3.2' }

      it { is_expected.to be true }
    end

    context 'v1.5.0' do
      let(:version) { '1.5.0' }

      it { is_expected.to be true }
    end
    
  end

  describe '.run' do
    subject { described_class.run '-V' }

    it { is_expected.to match /\d+\.\d+.\d+/ }
  end

end

