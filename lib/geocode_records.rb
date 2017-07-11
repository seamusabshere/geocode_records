require 'active_record'
require 'active_support'
require 'active_support/core_ext'
require 'attr_extras'
require 'pasqual'

require_relative 'geocode_records/version'
require_relative 'geocode_records/dump_sql_to_csv'
require_relative 'geocode_records/geocode_csv'
require_relative 'geocode_records/update_table_from_csv'
require_relative 'geocode_records/smarty_streets'

class GeocodeRecords

  attr_reader :records
  attr_reader :options
  def initialize(records, options = {})
    records.is_a?(ActiveRecord::Relation) or raise(ArgumentError, "expected AR::Relation, got #{records.class}")
    @options = (options || {}).symbolize_keys
    @records = records
  end
  
  def perform
    SmartyStreets.check_compatible!

    if records.count > 0
      # $stderr.puts "GeocodeRecords: #{records.count} to go!"
      ungeocoded_path = DumpSqlToCsv.new(pasqual, to_sql, options).path
      geocoded_path = GeocodeCsv.new(ungeocoded_path, options).path
      UpdateTableFromCsv.new(connection, table_name, geocoded_path, options).perform
      set_the_geom
      File.unlink geocoded_path
      File.unlink ungeocoded_path
    end
  end

  private

  def glob
    !!options[:glob]
  end

  def set_the_geom
    records.update_all <<-SQL
      the_geom              = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326),
      the_geom_webmercator  = ST_Transform(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326), 3857)
    SQL
  end

  def to_sql
    c = connection
    c.unprepared_statement do
      if glob
        c.to_sql records.select('id', 'glob').where.not(glob: nil).arel, records.bind_values
      else
        c.to_sql records.select('id', 'house_number_and_street', 'house_number', 'unit_number', 'city', 'state', "regexp_replace(postcode, '.0$', '') AS postcode").where('city IS NOT NULL OR postcode IS NOT NULL').arel, records.bind_values
      end
    end
  end

  def connection
    records.connection
  end

  def table_name
    @table_name = begin
      memo = options[:table_name]
      memo ||= records.table_name if records.respond_to?(:table_name)
      memo ||= records.engine.table_name
      memo
    end
  end

  def pasqual
    @pasqual ||= Pasqual.for ENV.fetch('DATABASE_URL')
  end
end
