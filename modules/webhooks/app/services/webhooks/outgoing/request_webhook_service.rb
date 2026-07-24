module Webhooks
  module Outgoing
    class RequestWebhookService
      include ::OpenProjectErrorHelper

      class TransientRequestError < StandardError; end

      TRANSIENT_RESPONSE_CODES = [408, 425, 429, *(500..599)].freeze
      TRANSIENT_EXCEPTIONS = [
        Net::OpenTimeout,
        Net::ReadTimeout,
        SocketError,
        EOFError,
        Errno::ECONNREFUSED,
        Errno::ECONNRESET,
        Errno::EHOSTUNREACH,
        Errno::ENETUNREACH
      ].freeze

      attr_reader :current_user, :event_name, :webhook

      def initialize(webhook, event_name:, current_user:)
        @current_user = current_user
        @webhook = webhook
        @event_name = event_name
      end

      def call!(body:, headers:)
        begin
          response = OpenProject::SsrfProtection.post(
            webhook.url,
            headers:,
            body:
          )
        rescue SsrfFilter::PrivateIPAddress => e
          message = "#{e.message} - If this is intentional, add the IP to the allowlist via " \
                    "the OPENPROJECT_SSRF_PROTECTION_IP_ALLOWLIST environment variable."
          op_handle_error(message, reference: :webhook_job)
          exception = e.exception(message)
        rescue StandardError => e
          op_handle_error(e.message, reference: :webhook_job)
          exception = e
        end

        log!(body:, headers:, response:, exception:)

        if transient_failure?(response:, exception:)
          detail = exception&.message || "HTTP #{response.code}"
          raise TransientRequestError, "Temporary webhook delivery failure: #{detail}"
        end
      end

      def log!(body:, headers:, response:, exception:)
        log = ::Webhooks::Log.new(
          webhook:,
          event_name:,
          url: webhook.url,
          request_headers: headers,
          request_body: body,
          **response_attributes(response:, exception:)
        )

        unless log.save
          OpenProject.logger.error("Failed to save webhook log: #{log.errors.full_messages.join('. ')}")
        end
      end

      def response_attributes(response:, exception:)
        {
          response_code: response&.code&.to_i || -1,
          response_headers: response_headers(response),
          response_body: response&.body || exception&.message
        }
      end

      def response_headers(response)
        response
          &.to_hash
          &.transform_keys { |k| k.underscore.to_sym }
          &.transform_values(&:first)
      end

      def transient_failure?(response:, exception:)
        return TRANSIENT_EXCEPTIONS.any? { |error_class| exception.is_a?(error_class) } if exception

        TRANSIENT_RESPONSE_CODES.include?(response&.code&.to_i)
      end
    end
  end
end
