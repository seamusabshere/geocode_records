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

    DESIRED_COLUMNS = %w{
      id
      ss_delivery_line_1
      ss_primary_number
      ss_secondary_number
      ss_city_name
      ss_state_abbreviation
      ss_zipcode
      ss_latitude
      ss_longitude
      ss_default_city_name
    }

    COPY_SQL = "\\copy $TMP_TABLE_NAME (#{DESIRED_COLUMNS.join(',')}) FROM '$PATH' DELIMITER ',' CSV HEADER"

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
        tmp_csv_path = strip_csv
        load_csv_into_tmp_table path: tmp_csv_path, table_name: tmp_table_name
        update_original_table tmp_table_name
      ensure
        delete_tmp_table tmp_table_name
      end
    end

    def create_tmp_table
      memo = "geocode_records_#{table_name}_#{rand(999999)}".gsub(/[^a-z0-9_]/i, '')
      GeocodeRecords.psql(
        database_url,
        CREATE_TABLE_SQL.sub('$TMP_TABLE_NAME', memo)
      )
      memo
    end

    def strip_csv
      memo = GeocodeRecords.new_tmp_path('stripped')
      GeocodeRecords.system(
        'xsv',
        'select', DESIRED_COLUMNS.join(','),
        path,
        out: memo
      )
      memo
    end

    def load_csv_into_tmp_table(path:, table_name:)
      GeocodeRecords.psql(
        database_url,
        COPY_SQL.sub('$TMP_TABLE_NAME', table_name).sub('$PATH', path)
      )
    end

    def update_original_table(tmp_table_name)
      GeocodeRecords.psql(
        database_url,
        UPDATE_TABLE_SQL.sub('$TMP_TABLE_NAME', tmp_table_name).sub('$TABLE_NAME', table_name)
      )
    end

    def delete_tmp_table(tmp_table_name)
      GeocodeRecords.psql(
        database_url,
        "DROP TABLE IF EXISTS #{tmp_table_name}"
      )
    end
  end
end
