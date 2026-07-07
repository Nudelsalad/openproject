# frozen_string_literal: true

class SerializedWebhookJob < WebhookJob
  attr_reader :project_id, :payload

  def perform(webhook_id, project_id, event_name, payload)
    @project_id = project_id
    @payload = payload
    super(webhook_id, event_name)

    return unless webhook.enabled_for_project?(project_id)

    body = payload.to_json
    headers = request_headers

    if (signature = request_signature(body))
      headers["X-OP-Signature"] = signature
    end

    ::Webhooks::Outgoing::RequestWebhookService
      .new(webhook, event_name:, current_user: User.system)
      .call!(body:, headers:)
  end

  def request_signature(request_body)
    if (secret = webhook.secret.presence)
      "sha1=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, request_body)}"
    end
  end

  def request_headers
    {
      "Content-Type": "application/json",
      Accept: "application/json"
    }
  end
end
