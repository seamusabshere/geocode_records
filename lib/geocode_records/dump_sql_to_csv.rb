class GeocodeRecords
  class DumpSqlToCsv
    attr_reader :database_url
    attr_reader :glob
    attr_reader :table_name
    attr_reader :subquery
    attr_reader :num

    def initialize(
      database_url:,
      glob:,
      table_name: nil,
      subquery: nil,
      num: nil
    )
      @database_url = database_url
      @glob = glob
      @table_name = table_name
      @subquery = subquery
      @num = num
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
      @sql ||= begin
        num_suffix = (num == 1 ? '' : num)
        unless glob
          "SELECT id, house_number_and_street#{num_suffix}, city#{num_suffix}, state#{num_suffix}, regexp_replace(postcode#{num_suffix}, '.0$', '') AS postcode#{num_suffix} FROM #{subquery ? "(#{subquery}) t1" : table_name} WHERE city#{num_suffix} IS NOT NULL OR postcode#{num_suffix} IS NOT NULL"
        else
          "SELECT id, glob#{num_suffix} FROM #{subquery ? "(#{subquery}) t1" : table_name} WHERE (city#{num_suffix} IS NULL AND postcode#{num_suffix} IS NULL) AND glob#{num_suffix} IS NOT NULL"
        end
      end
    end
  end
end
