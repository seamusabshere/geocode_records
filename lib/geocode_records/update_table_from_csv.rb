require 'csv'
require 'upsert'

class GeocodeRecords
  class UpdateTableFromCsv
    attr_private :connection
    attr_private :table_name
    attr_private :csv_path
    attr_private :upsert
    def initialize(connection, table_name, csv_path, ignored_options = {})
      @upsert = Upsert.new connection, table_name
      @csv_path = csv_path
    end
    def perform
      count = 0
      CSV.foreach(csv_path, headers: true) do |row|
        next unless row['postcode']
        row = row.to_hash
        if hn = row['house_number']
          row['house_number'] = hn.to_i
        end
        if default_city = row.delete('default_city')
          row['city'] = default_city
        end
        selector = { id: row.delete('id') }
        setter = row
        upsert.row selector, setter
        # $stderr.write "U#{count}..." if count % 1000 == 0
        count += 1
      end
      count
    end
  end
end
