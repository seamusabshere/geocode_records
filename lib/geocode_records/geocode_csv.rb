require 'json'

class GeocodeRecords
  class GeocodeCsv
    attr_reader :path
    attr_reader :glob
    attr_reader :include_invalid

    REQUIRED_SMARTYSTREETS_VERSION = Gem::Version.new('1.8.2')
    COLUMN_DEFINITION = {
      delivery_line_1: true,
      components: {
        primary_number: true,
        secondary_number: true,
        city_name: true,
        default_city_name: true,
        state_abbreviation: true,
        zipcode: true
      },
      metadata: {
        latitude: true,
        longitude: true
      }
    }

    def initialize(
      path:,
      glob:,
      include_invalid:
    )
      @path = path
      @glob = glob
      @include_invalid = include_invalid
    end

    def perform
      return unless File.size(path) > 32
      memo = GeocodeRecords.new_tmp_path File.basename("geocoded-#{path}")
      args = [
        smartystreets_bin_path,
        '-i', path,
        '-o', memo,
        '--quiet',
        '--auth-id', ENV.fetch('SMARTY_STREETS_AUTH_ID'),
        '--auth-token', ENV.fetch('SMARTY_STREETS_AUTH_TOKEN'),
        '--column-definition', JSON.dump(COLUMN_DEFINITION),
      ]
      if include_invalid
        args += [ '--include-invalid' ]
      end
      input_map.each do |ss, local|
        args += [ "--#{ss}-col", local.to_s ]
      end
      GeocodeRecords.system(*args)
      memo
    end

    private

    def input_map
      @input_map ||= if glob
        { 'street' => 'glob' }
      else
        {
          'street' => 'house_number_and_street',
          'zipcode' => 'postcode',
        }
      end
    end

    def smartystreets_bin_path
      @smartystreets_bin_path ||= begin
        memo = [
          'node_modules/.bin/smartystreets',
          `which smartystreets`.chomp
        ].compact.detect do |path|
          File.exist? path
        end
        raise "can't find smartystreets bin" unless memo
        version = Gem::Version.new `#{memo} -V`.chomp
        raise "smartystreets #{version} too old" unless version >= REQUIRED_SMARTYSTREETS_VERSION
        memo
      end
    end
  end
end
