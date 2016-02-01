require 'spec_helper'

dbname = 'geocode_records_test'
ENV['DATABASE_URL'] = "postgresql://127.0.0.1/#{dbname}"

unless ENV['FAST'] == 'true'
  psql = Pasqual.for ENV['DATABASE_URL']
  psql.dropdb rescue nil
  psql.createdb
  psql.command 'CREATE EXTENSION postgis'
  psql.command <<-SQL
  CREATE TABLE homes (
    id serial primary key,
    the_geom geometry(Geometry,4326),
    the_geom_webmercator geometry(Geometry,3857),
    house_number_and_street text,
    house_number int,
    unit_number text,
    city text,
    state text,
    postcode text,
    latitude float,
    longitude float
  )
  SQL
  psql.command <<-SQL
  CREATE TABLE glob_homes (
    id serial primary key,
    glob text,
    the_geom geometry(Geometry,4326),
    the_geom_webmercator geometry(Geometry,3857),
    house_number_and_street text,
    house_number int,
    unit_number text,
    city text,
    state text,
    postcode text,
    latitude float,
    longitude float
  )
  SQL
end

require 'active_record'
ActiveRecord::Base.establish_connection

class Home < ActiveRecord::Base
end
class GlobHome < ActiveRecord::Base
end

describe GeocodeRecords do
  it 'has a version number' do
    expect(GeocodeRecords::VERSION).not_to be nil
  end

  it "geocodes an AR::Relation" do
    home = Home.create! house_number_and_street: '1038 e deyton st', postcode: '53703'
    GeocodeRecords.new(Home.all).perform
    home.reload
    expect(home.house_number_and_street).to eq('1038 E Dayton St')
  end

  it "geocodes an AR::Relation with just a glob" do
    home = GlobHome.create! glob: '1038 e dayton st, madison, wi 53703'
    GeocodeRecords.new(GlobHome.all, glob: true).perform
    home.reload
    expect(home.house_number_and_street).to eq('1038 E Dayton St')
    expect(home.postcode).to eq('53703')
  end

  it "doesn't break on float-format postcode" do
    home = Home.create! house_number_and_street: '1038 e deyton st', postcode: '53703.0'
    GeocodeRecords.new(Home.all).perform
    home.reload
    expect(home.house_number_and_street).to eq('1038 E Dayton St')
  end

  it "doesn't break on unzeropadded postcode" do
    home = Home.create! house_number_and_street: '36 main st', postcode: '5753'
    GeocodeRecords.new(Home.all).perform
    home.reload
    expect(home.house_number_and_street).to eq('36 Main St')
  end

  it "doesn't break on unzeropadded float-format postcode" do
    home = Home.create! house_number_and_street: '36 main st', postcode: '5753.0'
    GeocodeRecords.new(Home.all).perform
    home.reload
    expect(home.house_number_and_street).to eq('36 Main St')
  end

  it "doesn't break on zip-4" do
    home = Home.create! house_number_and_street: '1038 e dayton st', postcode: '53703-2428'
    GeocodeRecords.new(Home.all).perform
    home.reload
    expect(home.house_number_and_street).to eq('1038 E Dayton St')
  end

  it "accepts city and state only" do
    home = Home.create! house_number_and_street: '1038 e dayton st', city: 'madison', state: 'wisconsin'
    GeocodeRecords.new(Home.all).perform
    home.reload
    expect(home.house_number_and_street).to eq('1038 E Dayton St')
  end

  it "allows invalid" do
    home = Home.create! house_number_and_street: '1039 e dayton st', city: 'madison', state: 'wisconsin'
    GeocodeRecords.new(Home.all, include_invalid: true).perform
    home.reload
    expect(home.house_number_and_street).to eq('1039 E Dayton St')
  end

  describe 'known issues' do
    it "doesn't fix float-format postcode on records that it can't geocode" do
      home = Home.create! house_number_and_street: 'gibberish', postcode: '53703.0'
      GeocodeRecords.new(Home.all).perform
      home.reload
      expect(home.house_number_and_street).to eq('gibberish')
      expect(home.postcode).to eq('53703.0')
    end

    it "doesn't fix unzeropadded postcode on records that it can't geocode" do
      home = Home.create! house_number_and_street: 'gibberish', postcode: '5753'
      GeocodeRecords.new(Home.all).perform
      home.reload
      expect(home.house_number_and_street).to eq('gibberish')
      expect(home.postcode).to eq('5753')
    end
  end

end
