require 'active_record'
require 'attr_extras'

require_relative 'geocode_records/version'
require_relative 'geocode_records/dump_sql_to_csv'
require_relative 'geocode_records/geocode_csv'
require_relative 'geocode_records/update_table_from_csv'

class GeocodeRecords

  attr_reader :records
  attr_reader :options
  def initialize(records, options = {})
    records.is_a?(ActiveRecord::Relation) or raise(ArgumentError, "expected AR::Relation, got #{records.class}")
    @options = options || {}
    @records = records
  end
  
  def perform
    if records.count > 0
      # $stderr.puts "GeocodeRecords: #{records.count} to go!"
      ungeocoded_path = DumpSqlToCsv.new(database, to_sql, options).path
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
        c.to_sql records.select('id', 'glob').arel, records.bind_values
      else
        c.to_sql records.select('id', 'house_number_and_street', 'house_number', 'unit_number', 'city', 'state', 'postcode').arel, records.bind_values
      end
    end
  end

  def connection
    records.connection
  end

  def table_name
    options[:table_name] || records.engine.table_name
  end

  def database
    records.engine.connection_config[:database]
  end
end
