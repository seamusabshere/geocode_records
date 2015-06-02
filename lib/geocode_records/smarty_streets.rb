class GeocodeRecords

  module SmartyStreets

    def self.bin_path
      @bin_path ||= if File.exist?('node_modules/.bin/smartystreets')
        'node_modules/.bin/smartystreets'
      else
        'smartystreets'
      end
    end

    def self.compatible?
      output = run('-V')
      current_version = Gem::Version.new output.chomp
      base_version = Gem::Version.new '1.3.2'
      current_version >= base_version
    end

    def self.run(*args)
      shargs = Shellwords.join(args)
      `#{bin_path} #{shargs}`
    end

  end

end
