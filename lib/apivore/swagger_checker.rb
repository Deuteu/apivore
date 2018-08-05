require 'English'

module Apivore
  class SwaggerChecker
    PATH_TO_CHECKER_MAP = {}

    def self.instance_for(path)
      PATH_TO_CHECKER_MAP[path] ||= new(path)
    end

    def path?(path)
      mappings.key?(path)
    end
    alias has_path? path? # TODO: Deprecate

    def method_at_path?(path, method)
      mappings[path].key?(method)
    end
    alias has_method_at_path? method_at_path? # TODO: Deprecate

    def response_code_for_path?(path, method, code)
      mappings[path][method].key?(code.to_s)
    end
    alias has_response_code_for_path? response_code_for_path? # TODO: Deprecate

    def response_codes_for_path(path, method)
      mappings[path][method].keys.join(', ')
    end

    def matching_document_for?(path, method, code, body)
      JSON::Validator.fully_validate(
        swagger, body, fragment: fragment(path, method, code)
      )
    end
    alias has_matching_document_for matching_document_for? # TODO: Deprecate

    def fragment(path, method, code)
      path_fragment = mappings[path][method.to_s][code.to_s]
      path_fragment.dup unless path_fragment.nil?
    end

    def remove_tested_end_point_response(path, method, code)
      return if untested_mappings[path].nil? || untested_mappings[path][method].nil?

      untested_mappings[path][method].delete(code.to_s)

      return unless untested_mappings[path][method].empty?

      untested_mappings[path].delete(method)

      untested_mappings.delete(path) if untested_mappings[path].empty?
    end

    def base_path
      @swagger.base_path
    end

    attr_reader :response, :swagger, :swagger_path, :untested_mappings
    attr_writer :response

    private

    attr_reader :mappings

    def initialize(swagger_path)
      @swagger_path = swagger_path
      load_swagger_doc!
      validate_swagger!
      setup_mappings!
    end

    def load_swagger_doc!
      @swagger = Apivore::Swagger.new(fetch_swagger!)
    end

    def fetch_swagger!
      session = ActionDispatch::Integration::Session.new(Rails.application)

      begin
        session.get(swagger_path)
      rescue StandardError
        raise "Unable to perform GET request for swagger json: #{swagger_path} - #{$ERROR_INFO}."
      end

      JSON.parse(session.response.body)
    end

    def validate_swagger!
      errors = swagger.validate
      return if errors.empty?

      msg = "The document fails to validate as Swagger #{swagger.version}:\n"
      msg += errors.join("\n")
      raise msg
    end

    def setup_mappings!
      @mappings = {}
      @swagger.each_response do |path, method, response_code, fragment|
        @mappings[path] ||= {}
        @mappings[path][method] ||= {}
        raise :duplicate unless @mappings[path][method][response_code].nil?
        @mappings[path][method][response_code] = fragment
      end

      @untested_mappings = JSON.parse(JSON.generate(@mappings))
    end
  end
end
