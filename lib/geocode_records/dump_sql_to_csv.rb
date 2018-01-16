class GeocodeRecords
  class DumpSqlToCsv
    attr_reader :database_url
    attr_reader :glob
    attr_reader :table_name
    attr_reader :subquery

    def initialize(
      database_url:,
      glob:,
      table_name: nil,
      subquery: nil)
      @database_url = database_url
      @glob = glob
      @table_name = table_name
      @subquery = subquery
    end

    def perform
      memo = GeocodeRecords.new_tmp_path(subquery || table_name)
      GeocodeRecords.psql(
        database_url,
        "\\copy (#{sql}) TO '#{memo}' DELIMITER ',' CSV HEADER" 
      )
      memo
    end

    private

    def sql
      @sql ||= unless glob
        "SELECT id, house_number_and_street, city, state, regexp_replace(postcode, '.0$', '') AS postcode FROM #{subquery ? "(#{subquery}) t1" : table_name} WHERE city IS NOT NULL OR postcode IS NOT NULL"
      else
        "SELECT id, glob FROM #{subquery ? "(#{subquery}) t1" : table_name} WHERE (city IS NULL AND postcode IS NULL) AND glob IS NOT NULL"
      end
    end
  end
end
