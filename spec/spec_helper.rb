$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'geocode_records'

require 'pry'

dbname = 'geocode_records_test'
ENV['DATABASE_URL'] = "postgresql://127.0.0.1:#{ENV['PGPORT'] || 5432}/#{dbname}"

unless ENV['FAST'] == 'true'
  GeocodeRecords.system('createdb', ENV.fetch('DATABASE_URL')) rescue nil
  GeocodeRecords.run_sql(
    ENV.fetch('DATABASE_URL'),
    'CREATE EXTENSION IF NOT EXISTS postgis'
  )
  GeocodeRecords.run_sql(
    ENV.fetch('DATABASE_URL'),
    'DROP TABLE IF EXISTS homes'
  )
  sql = <<-SQL
    CREATE TABLE homes (
      id uuid primary key,
      the_geom geometry(Geometry,4326),
      the_geom_webmercator geometry(Geometry,3857),
      glob text,
      house_number_and_street text,
      house_number int,
      unit_number text,
      city text,
      state text,
      postcode text,
      latitude float,
      longitude float,
      foo text
    )
  SQL
  GeocodeRecords.run_sql(
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
