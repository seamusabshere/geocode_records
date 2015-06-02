require 'spec_helper'

dbname = 'geocode_records_test'
ENV['DATABASE_URL'] ||= "postgresql://127.0.0.1/#{dbname}"

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
end

require 'active_record'
ActiveRecord::Base.establish_connection
# http://gray.fm/2013/09/17/unknown-oid-with-rails-and-postgresql/
require 'active_record/connection_adapters/postgresql/oid'
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.tap do |klass|
  klass::OID.register_type('geometry', klass::OID::Identity.new)
end

class Home < ActiveRecord::Base
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
