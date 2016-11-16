require 'mustache'

module RspecApiDocumentation
  module Views
    class MarkupExample < Mustache
      def initialize(example, configuration)
        @example = example
        @host = configuration.curl_host
        @filter_headers = configuration.curl_headers_to_filter
        self.template_path = configuration.template_path
      end

      def method_missing(method, *args, &block)
        @example.send(method, *args, &block)
      end

      def respond_to?(method, include_private = false)
        super || @example.respond_to?(method, include_private)
      end

      def dirname
        resource_name.to_s.downcase.gsub(/\s+/, '_').gsub(":", "_")
      end

      def filename
        basename = description.downcase.gsub(/\s+/, '_').gsub(Pathname::SEPARATOR_PAT, '')
        basename = Digest::MD5.new.update(description).to_s if basename.blank?
        "#{basename}.#{extension}"
      end

      def parameters
        super.each do |parameter|
          if parameter.has_key?(:scope)
            scope = Array(parameter[:scope]).each_with_index.map do |scope, index|
              if index == 0
                scope
              else
                "[#{scope}]"
              end
            end.join
            parameter[:scope] = scope
          end
        end
      end

      def requests
        super.map do |hash|
          hash[:request_content_type] = content_type(hash[:request_headers])
          hash[:request_headers_text] = format_hash(hash[:request_headers])
          hash[:request_query_parameters_text] = format_hash(hash[:request_query_parameters])
          hash[:response_content_type] = content_type(hash[:response_headers])
          hash[:response_headers_text] = format_hash(hash[:response_headers])
          hash[:has_request?] = has_request?(hash)
          hash[:has_response?] = has_response?(hash)
          if @host
            if hash[:curl].is_a? RspecApiDocumentation::Curl
              hash[:curl] = hash[:curl].output(@host, @filter_headers)
            end
          else
            hash[:curl] = nil
          end
          hash
        end
      end

      def extension
        raise 'Parent class. This method should not be called.'
      end

      private

      def has_request?(metadata)
        metadata.any? do |key, value|
          [:request_body, :request_headers, :request_content_type].include?(key) && value
        end
      end

      def has_response?(metadata)
        metadata.any? do |key, value|
          [:response_status, :response_body, :response_headers, :response_content_type].include?(key) && value
        end
      end

      def format_hash(hash = {})
        return nil unless hash.present?
        hash.collect do |k, v|
          "#{k}: #{v}"
        end.join("\n")
      end

      def content_type(headers)
        headers && headers.fetch("Content-Type", nil)
      end
    end
  end
end
