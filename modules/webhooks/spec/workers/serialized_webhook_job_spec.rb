# frozen_string_literal: true

require "spec_helper"

RSpec.describe SerializedWebhookJob, :webmock, type: :job do
  include_context "with ssrf stubs"

  shared_let(:request_url) { "http://example.net/test/42" }
  shared_let(:project) { create(:project) }
  shared_let(:webhook) { create(:webhook, all_projects: true, url: request_url, secret: nil) }

  let(:event) { "time_entry:deleted" }
  let(:payload) do
    {
      "action" => event,
      "time_entry" => {
        "_type" => "TimeEntry",
        "id" => 42
      }
    }
  end
  let(:request_headers) do
    { "Content-Type": "application/json", Accept: "application/json" }
  end
  let(:stub) do
    stub_request(:post, request_url)
      .with(
        body: payload,
        headers: request_headers.merge(host: "example.net")
      )
      .to_return(status: 200, body: "hook called", headers: { content_type: "text/plain" })
  end

  before do
    allow(Webhooks::Webhook).to receive(:find).with(webhook.id).and_return(webhook)
    stub
  end

  it "posts the serialized payload" do
    described_class.perform_now(webhook.id, project.id, event, payload)

    expect(stub).to have_been_requested
  end

  it "does not request when project does not match" do
    allow(webhook)
      .to receive(:enabled_for_project?).with(project.id)
      .and_return(false)

    described_class.perform_now(webhook.id, project.id, event, payload)

    expect(stub).not_to have_been_requested
  end
end
