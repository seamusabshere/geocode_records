require 'json'

class GeocodeRecords
  class GeocodeCsv
    attr_reader :path
    attr_reader :glob
    attr_reader :include_invalid
    attr_reader :num

    REQUIRED_SMARTYSTREETS_VERSION = Gem::Version.new('1.8.2')
    COLUMN_DEFINITION = {
      delivery_line_1: true,
      components: {
        street_predirection: true,
        street_name: true,
        street_suffix: true,
        street_postdirection: true,
        primary_number: true,
        secondary_number: true,
        city_name: true,
        default_city_name: true,
        state_abbreviation: true,
        zipcode: true,
        plus4_code: true,
      },
      metadata: {
        latitude: true,
        longitude: true
      }
    }

    def initialize(
      path:,
      glob:,
      include_invalid:,
      num:
    )
      @path = path
      @glob = glob
      @include_invalid = include_invalid
      @num = num
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
      @input_map ||= begin
        num_suffix = (num == 1 ? '' : num)
        if glob
          { 'street' => "glob#{num_suffix}" }
        else
          {
            'street' => "house_number_and_street#{num_suffix}",
            'zipcode' => "postcode#{num_suffix}",
            'city' => "city#{num_suffix}",
            'state' => "state#{num_suffix}",
          }
        end
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
