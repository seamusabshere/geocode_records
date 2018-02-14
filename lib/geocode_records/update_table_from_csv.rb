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
        ss_plus4_code text,
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
      ss_plus4_code
      ss_latitude
      ss_longitude
      ss_default_city_name
    }

    COPY_SQL = "\\copy $TMP_TABLE_NAME (#{DESIRED_COLUMNS.join(',')}) FROM '$PATH' DELIMITER ',' CSV HEADER"

    UPDATE_TABLE_SQL = (<<-SQL).gsub('      ', '').freeze
      UPDATE $TABLE_NAME AS target
      SET
        house_number_and_street$NUM_SUFFIX = src.ss_delivery_line_1,
        house_number$NUM_SUFFIX = CASE
          WHEN src.ss_primary_number IS NULL THEN NULL
          WHEN LENGTH(src.ss_primary_number) > 8 THEN NULL
          WHEN src.ss_primary_number ~ '\\A\\d+\\Z' THEN src.ss_primary_number::int
          WHEN src.ss_primary_number ~ '/' THEN (SELECT regexp_matches(src.ss_primary_number, '(\\d+)'))[1]::int
          WHEN src.ss_primary_number ~ '-' THEN (SELECT ROUND(AVG(v)) FROM unnest(array_remove(regexp_split_to_array(src.ss_primary_number, '\\D+'), '')::int[]) v)
          ELSE (SELECT regexp_matches(src.ss_primary_number, '(\\d+)'))[1]::int
        END,
        unit_number$NUM_SUFFIX = src.ss_secondary_number,
        city$NUM_SUFFIX = COALESCE(src.ss_default_city_name, src.ss_city_name),
        state$NUM_SUFFIX = src.ss_state_abbreviation,
        postcode$NUM_SUFFIX = src.ss_zipcode,
        postcode_zip4$NUM_SUFFIX = src.ss_plus4_code,
        latitude$NUM_SUFFIX = src.ss_latitude,
        longitude$NUM_SUFFIX = src.ss_longitude
      FROM $TMP_TABLE_NAME AS src
      WHERE
            target.id = src.id
        AND src.ss_zipcode IS NOT NULL
    SQL

    attr_reader :database_url
    attr_reader :table_name
    attr_reader :path
    attr_reader :num

    def initialize(
      database_url:,
      table_name:,
      path:,
      num:
    )
      @database_url = database_url
      @table_name = table_name
      @path = path
      @num = num
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
        CREATE_TABLE_SQL.gsub('$TMP_TABLE_NAME', memo)
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
        COPY_SQL.gsub('$TMP_TABLE_NAME', table_name).gsub('$PATH', path)
      )
    end

    def update_original_table(tmp_table_name)
      num_suffix = (num == 1 ? '' : num.to_s)
      GeocodeRecords.psql(
        database_url,
        UPDATE_TABLE_SQL.gsub('$TMP_TABLE_NAME', tmp_table_name).gsub('$TABLE_NAME', table_name).gsub('$NUM_SUFFIX', num_suffix)
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
