require 'tmpdir'
require 'fileutils'
require 'csv'
require 'shellwords'
require 'zaru'

# copied from hotdog/app/services/file_geocoder.rb with seamus variations
class GeocodeRecords
  class GeocodeCsv
    attr_reader :glob

    def initialize(input_path, options = {})
      @input_path = input_path
      options ||= {}
      @glob = options[:glob]
      @mutex = Mutex.new
    end

    def path
      return if @path
      @mutex.synchronize do
        return if @path
        geocode
        recode
        @path = @recoded_path
      end
    end

    private

    attr_private :input_path
    attr_private :geocoded_path
    attr_private :recoded_path

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

    def geocode
      @geocoded_path = Dir::Tmpname.create(Zaru.sanitize!(input_path + '.geocode')) {}
      args = [
        'smartystreets',
        '-i', input_path,
        '-o', geocoded_path,
        '--auth-id', ENV.fetch('SMARTY_STREETS_AUTH_ID'),
        '--auth-token', ENV.fetch('SMARTY_STREETS_AUTH_TOKEN')
      ]
      input_map.each do |ss, local|
        args += [ "--#{ss}-col", local.to_s ]
      end
      system(*args)
      raise "Geocoding failed on #{input_path.inspect} with args #{Shellwords.join(args)}" unless $?.success?
    end

    def recode
      @recoded_path = Dir::Tmpname.create(Zaru.sanitize!(input_path + '.recode')) {}
      File.open(@recoded_path, 'w') do |f|
        f.write output_columns.to_csv
        CSV.foreach(@geocoded_path, headers: true) do |geocoded_row|
          f.write recode_columns.map { |k| geocoded_row[k] }.to_csv
        end
      end
      File.unlink @geocoded_path
    end

    def output_columns
      @output_columns ||= (File.open(input_path) { |f| CSV.parse_line(f.gets) } + RECODE_MAP.keys).uniq
    end

    # no street yet - street_name, street_suffix
    RECODE_MAP = {
      'house_number_and_street' => 'ss_delivery_line_1',
      'house_number' => 'ss_primary_number',
      'unit_number' => 'ss_secondary_number',
      'city' => 'ss_city_name',
      'state' => 'ss_state_abbreviation',
      'postcode' => 'ss_zipcode',
      'latitude' => 'ss_latitude',
      'longitude' => 'ss_longitude',
    }.freeze

    def recode_columns
      @recode_columns ||= output_columns.map do |output_k|
        RECODE_MAP[output_k] || output_k
      end
    end
  end
end
