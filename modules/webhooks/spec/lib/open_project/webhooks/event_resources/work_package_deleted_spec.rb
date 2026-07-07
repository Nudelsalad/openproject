# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenProject::Webhooks::EventResources::WorkPackageDeleted do
  shared_let(:work_package) { create(:work_package) }
  shared_let(:actor) { create(:user) }
  let!(:deleted_webhook) { create(:webhook, event_names: ["work_package:deleted"]) }

  it "invokes deleted webhooks with a serialized payload" do
    OpenProject::Notifications.send(OpenProject::Events::WORK_PACKAGE_DESTROYED, work_package:, actor:)

    expect(SerializedWebhookJob).to have_been_enqueued.with(
      deleted_webhook.id,
      work_package.project_id,
      "work_package:deleted",
      hash_including(
        "action" => "work_package:deleted",
        "work_package" => hash_including(
          "_type" => "WorkPackage",
          "id" => work_package.id,
          "project_id" => work_package.project_id
        ),
        "actor" => hash_including("_type" => "User", "id" => actor.id)
      )
    )
  end
end
