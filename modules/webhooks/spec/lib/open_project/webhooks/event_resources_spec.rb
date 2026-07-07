# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenProject::Webhooks::EventResources do
  describe ".available_events_map" do
    it "groups work package delete events with other work package events" do
      expect(described_class.available_events_map[I18n.t(:label_work_package_plural)].keys)
        .to include("work_package:created", "work_package:updated", "work_package:deleted")
    end
  end
end
