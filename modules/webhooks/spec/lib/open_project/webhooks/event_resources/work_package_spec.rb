# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenProject::Webhooks::EventResources::WorkPackage do
  shared_let(:work_package) { create(:work_package) }
  shared_let(:actor) { create(:user) }
  let!(:created_webhook) { create(:webhook, event_names: ["work_package:created"]) }
  let!(:updated_webhook) { create(:webhook, event_names: ["work_package:updated"]) }

  it "invokes created webhooks from initial journals" do
    journal = create(:work_package_journal, journable: work_package, user: actor, version: 1)

    OpenProject::Notifications.send(OpenProject::Events::AGGREGATED_WORK_PACKAGE_JOURNAL_READY, journal:)

    expect(WorkPackageWebhookJob).to have_been_enqueued.with(
      created_webhook.id,
      work_package,
      "work_package:created",
      actor:
    )
  end

  it "invokes updated webhooks from non-initial journals" do
    journal = create(:work_package_journal, journable: work_package, user: actor, version: 2)

    OpenProject::Notifications.send(OpenProject::Events::AGGREGATED_WORK_PACKAGE_JOURNAL_READY, journal:)

    expect(WorkPackageWebhookJob).to have_been_enqueued.with(
      updated_webhook.id,
      work_package,
      "work_package:updated",
      actor:
    )
  end
end
