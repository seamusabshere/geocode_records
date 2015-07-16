class GeocodeRecords

  module SmartyStreets

    VERSION = '1.6.2'

    def self.bin_path
      @bin_path ||= if File.exist?('node_modules/.bin/smartystreets')
        'node_modules/.bin/smartystreets'
      else
        'smartystreets'
      end
    end

    def self.check_compatible!
      raise "smartystreets >= #{VERSION} is required" unless SmartyStreets.compatible?
    end

    def self.compatible?
      output = run_with_output('-V')
      current_version = Gem::Version.new output.chomp
      min_version = Gem::Version.new VERSION
      current_version >= min_version
    end

    def self.run(*args)
      shargs = Shellwords.join(args)
      system "#{bin_path} #{shargs}"
    end
    
    def self.run_with_output(*args)
      shargs = Shellwords.join(args)
      `#{bin_path} #{shargs}`
    end

  end

end
