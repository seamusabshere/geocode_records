require 'spec_helper'

describe GeocodeRecords do
  subject { GeocodeRecords.new(database_url: ENV.fetch('DATABASE_URL'), table_name: 'homes').perform }
  
  it "geocodes" do
    home = Home.create! house_number_and_street: '123 n blount st apt 403', postcode: '53703'
    subject
    home.reload
    expect(home.house_number_and_street).to eq('123 N Blount St Unit 403')
    expect(home.street).to eq('N Blount St')
    expect(home.unit_number).to eq('403')
    expect(home.house_number).to eq(123)
    expect(home.latitude).to be_present
  end

  it "geocodes addr 2" do
    home = Home.create! house_number_and_street2: '123 n blount st apt 403', postcode2: '53703'
    GeocodeRecords.new(database_url: ENV.fetch('DATABASE_URL'), table_name: 'homes', num: 2).perform
    home.reload
    expect(home.house_number_and_street2).to eq('123 N Blount St Unit 403')
    expect(home.street2).to eq('N Blount St')
    expect(home.unit_number2).to eq('403')
    expect(home.house_number2).to eq(123)
    expect(home.latitude2).to be_present
  end

  it "geocodes quoted table name" do
    home = Home.create! house_number_and_street: '1038 e deyton st', postcode: '53703'
    GeocodeRecords.new(database_url: ENV.fetch('DATABASE_URL'), table_name: '"homes"').perform
    home.reload
    expect(home.house_number_and_street).to eq('1038 E Dayton St')
  end

  it "geocodes glob" do
    home = Home.create! glob: '1038 e dayton st, madison, wi 53703'
    subject
    home.reload
    expect(home.house_number_and_street).to eq('1038 E Dayton St')
    expect(home.postcode).to eq('53703')
  end

  it "geocodes glob2" do
    home = Home.create! glob2: '1038 e dayton st, madison, wi 53703'
    GeocodeRecords.new(database_url: ENV.fetch('DATABASE_URL'), table_name: 'homes', num: 2).perform
    home.reload
    expect(home.house_number_and_street2).to eq('1038 E Dayton St')
    expect(home.postcode2).to eq('53703')
  end

  it "geocodes by sql" do
    home = Home.create! house_number_and_street: '1038 e deyton st', postcode: '53703', foo: 'bar'
    home_ignored = Home.create! house_number_and_street: '1038 e deyton st', postcode: '53703'
    GeocodeRecords.new(database_url: ENV.fetch('DATABASE_URL'), table_name: 'homes', subquery: %{SELECT * FROM homes WHERE foo = 'bar'}).perform  
    home.reload
    home_ignored.reload
    expect(home.latitude).to be_present
    expect(home_ignored.latitude).to be_nil
  end

  it "geocodes by sql num 2" do
    home = Home.create! house_number_and_street2: '1038 e deyton st', postcode2: '53703', foo: 'bar'
    home_ignored = Home.create! house_number_and_street2: '1038 e deyton st', postcode2: '53703'
    GeocodeRecords.new(database_url: ENV.fetch('DATABASE_URL'), table_name: 'homes', subquery: %{SELECT * FROM homes WHERE foo = 'bar'}, num: 2).perform  
    home.reload
    home_ignored.reload
    expect(home.latitude2).to be_present
    expect(home_ignored.latitude2).to be_nil
  end

  it "doesn't break on float-format postcode" do
    home = Home.create! house_number_and_street: '1038 e deyton st', postcode: '53703.0'
    subject
    home.reload
    expect(home.house_number_and_street).to eq('1038 E Dayton St')
  end

  it "doesn't break on unzeropadded postcode" do
    home = Home.create! house_number_and_street: '36 main st', postcode: '5753'
    subject
    home.reload
    expect(home.house_number_and_street).to eq('36 Main St')
  end

  it "doesn't break on unzeropadded float-format postcode" do
    home = Home.create! house_number_and_street: '36 main st', postcode: '5753.0'
    subject
    home.reload
    expect(home.house_number_and_street).to eq('36 Main St')
  end

  it "doesn't break on zip-4" do
    home = Home.create! house_number_and_street: '1038 e dayton st', postcode: '53703-2428'
    subject
    home.reload
    expect(home.house_number_and_street).to eq('1038 E Dayton St')
  end

  it "accepts city and state only" do
    home = Home.create! house_number_and_street: '1038 e dayton st', city: 'madison', state: 'wisconsin'
    subject
    home.reload
    expect(home.house_number_and_street).to eq('1038 E Dayton St')
  end

  it "allows invalid" do
    home = Home.create! house_number_and_street: '1039 e dayton st', city: 'madison', state: 'wisconsin'
    GeocodeRecords.new(database_url: ENV.fetch('DATABASE_URL'), table_name: 'homes', include_invalid: true).perform
    home.reload
    expect(home.house_number_and_street).to eq('1039 E Dayton St')
  end

  it "overwrites unit" do
    home = Home.create! house_number_and_street: '123 n blount st apt 403', city: 'madison', state: 'wisconsin'
    GeocodeRecords.new(database_url: ENV.fetch('DATABASE_URL'), table_name: 'homes', include_invalid: true).perform
    home.reload
    expect(home.house_number_and_street).to eq('123 N Blount St Unit 403')
  end

  it "overwrites city name with default_city_name" do
    home = Home.create! house_number_and_street: '7333 Bay Bridge Rd', city: 'eastvale', state: 'ca'
    GeocodeRecords.new(database_url: ENV.fetch('DATABASE_URL'), table_name: 'homes', include_invalid: true).perform
    home.reload
    expect(home.city).to eq('Corona')
  end

  describe 'known issues' do
    it "doesn't fix float-format postcode on records that it can't geocode" do
      home = Home.create! house_number_and_street: 'gibberish', postcode: '53703.0'
      subject
      home.reload
      expect(home.house_number_and_street).to eq('gibberish')
      expect(home.postcode).to eq('53703.0')
    end

    it "doesn't fix unzeropadded postcode on records that it can't geocode" do
      home = Home.create! house_number_and_street: 'gibberish', postcode: '5753'
      subject
      home.reload
      expect(home.house_number_and_street).to eq('gibberish')
      expect(home.postcode).to eq('5753')
    end
  end

end
