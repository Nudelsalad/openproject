# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenProject::Webhooks::EventResources::TimeEntry do
  shared_let(:time_entry) { create(:time_entry) }
  let!(:created_webhook) { create(:webhook, event_names: ["time_entry:created"]) }
  let!(:updated_webhook) { create(:webhook, event_names: ["time_entry:updated"]) }
  let!(:deleted_webhook) { create(:webhook, event_names: ["time_entry:deleted"]) }

  it "invokes created webhooks" do
    OpenProject::Notifications.send(OpenProject::Events::TIME_ENTRY_CREATED, time_entry:)

    expect(TimeEntryWebhookJob).to have_been_enqueued.with(
      created_webhook.id,
      time_entry,
      "time_entry:created"
    )
  end

  it "invokes updated webhooks" do
    OpenProject::Notifications.send(OpenProject::Events::TIME_ENTRY_UPDATED, time_entry:)

    expect(TimeEntryWebhookJob).to have_been_enqueued.with(
      updated_webhook.id,
      time_entry,
      "time_entry:updated"
    )
  end

  it "invokes deleted webhooks with a serialized payload" do
    OpenProject::Notifications.send(OpenProject::Events::TIME_ENTRY_DESTROYED, time_entry:)

    expect(SerializedWebhookJob).to have_been_enqueued.with(
      deleted_webhook.id,
      time_entry.project_id,
      "time_entry:deleted",
      hash_including(
        "action" => "time_entry:deleted",
        "time_entry" => hash_including(
          "_type" => "TimeEntry",
          "id" => time_entry.id,
          "project_id" => time_entry.project_id
        )
      )
    )
  end
end
