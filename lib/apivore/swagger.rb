require 'hashie'

require 'apivore/fragment'

module Apivore
  class Swagger < Hashie::Mash
    NONVERB_PATH_ITEMS = 'parameters'.freeze

    def validate
      case version
      when '2.0'
        schema = File.read(File.expand_path('../../data/swagger_2.0_schema.json', __dir__))
      else
        raise "Unknown/unsupported Swagger version to validate against: #{version}"
      end
      JSON::Validator.fully_validate(schema, self)
    end

    def version
      swagger
    end

    def base_path
      self['basePath'] || ''
    end

    def each_response
      paths.each do |path, path_data|
        next if vendor_specific_tag? path
        path_data.each do |verb, method_data|
          next if NONVERB_PATH_ITEMS.include?(verb)
          next if vendor_specific_tag?(verb)
          if method_data.responses.nil?
            raise "No responses found in swagger for path '#{path}', method #{verb}: #{method_data.inspect}"
          end

          method_data.responses.each do |response_code, response_data|
            schema_location = nil
            if response_data.schema
              schema_location = Fragment.new ['#', 'paths', path, verb, 'responses', response_code, 'schema']
            end

            yield(path, verb, response_code, schema_location)
          end
        end
      end
    end

    def vendor_specific_tag?(tag)
      tag =~ /\Ax-.*/
    end
  end
end
