require 'csv'

class GeocodeRecords
  class UpdateTableFromCsv
    CREATE_TABLE_SQL = (<<-SQL).gsub('      ', '').freeze
      CREATE TABLE $TMP_TABLE_NAME (
        id uuid primary key,
        ss_delivery_line_1 text,
        ss_primary_number text,
        ss_secondary_number text,
        ss_city_name text,
        ss_state_abbreviation text,
        ss_zipcode text,
        ss_latitude float,
        ss_longitude float,
        ss_default_city_name text
      )
    SQL

    PGLOADER_CONFIG = <<-SQL
      LOAD CSV
      FROM '$PATH'
      (
        $INPUT_COLUMNS
      )
      INTO $DATABASE_URL?$TMP_TABLE_NAME
      (
        id,
        ss_delivery_line_1,
        ss_primary_number,
        ss_secondary_number,
        ss_city_name,
        ss_state_abbreviation,
        ss_zipcode,
        ss_latitude,
        ss_longitude,
        ss_default_city_name
      )
      WITH
        skip header = 1,
        fields optionally enclosed by '"',
        fields escaped by double-quote,
        fields terminated by ','
      SET client_encoding to 'utf8';
    SQL

    UPDATE_TABLE_SQL = (<<-SQL).gsub('      ', '').freeze
      UPDATE $TABLE_NAME AS target
      SET
        house_number_and_street = src.ss_delivery_line_1,
        house_number = CASE WHEN LENGTH(src.ss_primary_number) > 7 THEN NULL ELSE src.ss_primary_number::int END,
        unit_number = src.ss_secondary_number,
        city = COALESCE(src.ss_default_city_name, src.ss_city_name),
        state = src.ss_state_abbreviation,
        postcode = src.ss_zipcode,
        latitude = src.ss_latitude,
        longitude = src.ss_longitude
      FROM $TMP_TABLE_NAME AS src
      WHERE
            target.id = src.id
        AND src.ss_zipcode IS NOT NULL
    SQL

    attr_reader :database_url
    attr_reader :table_name
    attr_reader :path

    def initialize(
      database_url:,
      table_name:,
      path:
    )
      @database_url = database_url
      @table_name = table_name
      @path = path
    end

    def perform
      return unless File.size(path) > 32
      tmp_table_name = create_tmp_table
      begin
        load_csv_into_tmp_table tmp_table_name
        update_original_table tmp_table_name
      ensure
        delete_tmp_table tmp_table_name
      end
    end

    def create_tmp_table
      memo = "geocode_records_#{table_name}_#{rand(999999)}".gsub(/[^a-z0-9_]/i, '')
      GeocodeRecords.run_sql(
        database_url,
        CREATE_TABLE_SQL.sub('$TMP_TABLE_NAME', memo)
      )
      memo
    end

    def load_csv_into_tmp_table(tmp_table_name)
      pg_loader_config_path = GeocodeRecords.new_tmp_path('pgloader')
      File.open(pg_loader_config_path, 'w') { |f| f.write PGLOADER_CONFIG.sub('$INPUT_COLUMNS', input_columns.join(',')).sub('$DATABASE_URL', database_url).sub('$TMP_TABLE_NAME', tmp_table_name).sub('$PATH', path) }
      GeocodeRecords.system(
        'pgloader',
        # '--debug',
        '--quiet',
        pg_loader_config_path
      )
      File.unlink pg_loader_config_path
    end

    def update_original_table(tmp_table_name)
      GeocodeRecords.run_sql(
        database_url,
        UPDATE_TABLE_SQL.sub('$TMP_TABLE_NAME', tmp_table_name).sub('$TABLE_NAME', table_name)
      )
    end

    def delete_tmp_table(tmp_table_name)
      GeocodeRecords.run_sql(
        database_url,
        "DROP TABLE IF EXISTS #{tmp_table_name}"
      )
    end

    def input_columns
      CSV.parse_line(File.open(path) { |f| f.gets }).map do |col|
        "#{col} [NULL IF BLANKS]"
      end
    end
  end
end
