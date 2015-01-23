require 'shellwords'

class GeocodeRecords
  class DumpSqlToCsv
    attr_private :database
    attr_private :sql
    def initialize(database, sql, ignored_options = {})
      @database = database
      @sql = sql
    end

    def path
      @path = Dir::Tmpname.create(sql[0,64].delete('"').gsub(/\W/,'_').squeeze) {}
      system(
        'psql',
        database,
        '--command', "\\copy (#{sql}) TO '#{@path}' DELIMITER ',' CSV HEADER"
      )
      @path
    end

    private

    def system(*args)
      super(*args)
      raise "DumpSqlToCsv failed: #{Shellwords.join(args)}" unless $?.success?
    end
  end
end
