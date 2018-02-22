$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'geocode_records'

require 'pry'

dbname = 'geocode_records_test'
ENV['DATABASE_URL'] = "postgresql://127.0.0.1:#{ENV['PGPORT'] || 5432}/#{dbname}"

unless ENV['FAST'] == 'true'
  GeocodeRecords.system('createdb', ENV.fetch('DATABASE_URL')) rescue nil
  GeocodeRecords.psql(
    ENV.fetch('DATABASE_URL'),
    'CREATE EXTENSION IF NOT EXISTS postgis'
  )
  GeocodeRecords.psql(
    ENV.fetch('DATABASE_URL'),
    'DROP TABLE IF EXISTS homes'
  )
  sql = <<-SQL
    CREATE TABLE homes (
      id uuid primary key,
      the_geom geometry(Geometry,4326),
      the_geom_webmercator geometry(Geometry,3857),
      glob text,
      street text,
      house_number_and_street text,
      house_number int,
      unit_number text,
      city text,
      state text,
      postcode text,
      postcode_zip4 text,
      latitude float,
      longitude float,
      glob2 text,
      street2 text,
      house_number_and_street2 text,
      house_number2 int,
      unit_number2 text,
      city2 text,
      state2 text,
      postcode2 text,
      postcode_zip42 text,
      latitude2 float,
      longitude2 float,
      foo text
    )
  SQL
  GeocodeRecords.psql(
    ENV.fetch('DATABASE_URL'),
    sql
  )
end

require 'active_record'
ActiveRecord::Base.establish_connection

require 'logger'
require 'fileutils'
FileUtils.mkdir_p 'log'
logger = Logger.new 'log/test.log'
ActiveRecord::Base.logger = logger

require 'securerandom'
class Home < ActiveRecord::Base
  self.primary_key = 'id'
  before_create do
    self.id ||= SecureRandom.uuid
  end
end

RSpec.configure do |config|
  config.before :each do |example|
    Home.delete_all
  end
end
