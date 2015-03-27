class DumpSqlToCsv
  attr_private :sql
  attr_private :pasqual

  def initialize(pasqual, sql, ignored_options = {})
    @pasqual = pasqual
    @sql = sql
  end

  def path
    @path = Dir::Tmpname.create(sql[0,64].delete('"').gsub(/\W/,'_').squeeze) {}

    pasqual.command "\\copy (#{sql}) TO '#{@path}' DELIMITER ',' CSV HEADER"

    @path
  end

end
