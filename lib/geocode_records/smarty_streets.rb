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
      output = run('-V').scan(/\A(\d+)\.(\d+)\.(\d+)/).first
      major, minor, patch = [$1, $2, $3].map(&:to_i)
      major >= 1 and minor >= 3 and patch >= 2
    end

    def self.run(*args)
      shargs = Shellwords.join(args)
      `#{bin_path} #{shargs}`
    end

  end

end
