require 'active_support'
require 'active_support/core_ext'
require 'tmpdir'
require 'shellwords'
require 'fileutils'

require_relative 'geocode_records/version'
require_relative 'geocode_records/dump_sql_to_csv'
require_relative 'geocode_records/geocode_csv'
require_relative 'geocode_records/update_table_from_csv'

class GeocodeRecords
  class << self
    def new_tmp_path(hint)
      Dir::Tmpname.create(hint[0,64].delete('"').gsub(/\W/,'_').squeeze) {}
    end

    def system(*args)
      result = Kernel.system(*args)
      unless result
        raise "failed command:\n#{Shellwords.join args}"
      end
      nil
    end

    def psql(database_url, sql)
      system(
        'psql',
        database_url,
        '-v', 'ON_ERROR_STOP=on',
        # '--echo-all',
        '--quiet',
        '--no-psqlrc',
        '--pset', 'pager=off',
        '--command', sql
      )
    end
  end

  attr_reader :database_url
  attr_reader :table_name

  # optional
  attr_reader :include_invalid
  attr_reader :subquery
  attr_reader :num

   def initialize(
    database_url:,
    table_name:,
    subquery: nil,
    include_invalid: false,
    num: 1
  )
    @database_url = database_url
    @table_name = table_name
    @subquery = subquery
    @include_invalid = include_invalid
    @num = num
  end
  
  def perform
    geocode glob: false
    geocode glob: true
  end

  private

  def geocode(glob:)
    ungeocoded_path = nil
    geocoded_path = nil
    begin
      ungeocoded_path = DumpSqlToCsv.new(
        database_url: database_url,
        table_name: table_name,
        subquery: subquery,
        glob: glob,
        num: num,
      ).perform
      unless File.size(ungeocoded_path) > 32
        return
      end
      geocoded_path = GeocodeCsv.new(
        path: ungeocoded_path,
        glob: glob,
        include_invalid: include_invalid,
        num: num,
      ).perform
      UpdateTableFromCsv.new(
        database_url: database_url,
        table_name: table_name,
        path: geocoded_path,
        num: num,
      ).perform
    ensure
      FileUtils.rm_f geocoded_path if geocoded_path
      FileUtils.rm_f ungeocoded_path if ungeocoded_path
    end
  end
end
