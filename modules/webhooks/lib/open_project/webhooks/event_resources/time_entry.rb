require_relative "base"

module OpenProject::Webhooks::EventResources
  class TimeEntry < Base
    class << self
      def notification_names
        [
          OpenProject::Events::TIME_ENTRY_CREATED,
          OpenProject::Events::TIME_ENTRY_UPDATED,
          OpenProject::Events::TIME_ENTRY_DESTROYED
        ]
      end

      def available_actions
        %i(created updated deleted)
      end

      def resource_name
        I18n.t "webhooks.resources.time_entry.name"
      end

      protected

      def handle_notification(payload, event_name)
        action = event_name.split("_").last == "destroyed" ? "deleted" : event_name.split("_").last
        event_name = prefixed_event_name(action)

        if action == "deleted"
          enqueue_deleted_webhooks(payload[:time_entry], event_name)
          return
        end

        active_webhooks.with_event_name(event_name).pluck(:id).each do |id|
          TimeEntryWebhookJob.perform_later(id, payload[:time_entry], event_name)
        end
      end

      def enqueue_deleted_webhooks(time_entry, event_name)
        body = deleted_payload(event_name, time_entry)
        active_webhooks.with_event_name(event_name).pluck(:id).each do |id|
          SerializedWebhookJob.perform_later(id, time_entry.project_id, event_name, body)
        end
      end

      def deleted_payload(event_name, time_entry)
        {
          action: event_name,
          time_entry: {
            _type: "TimeEntry",
            id: time_entry.id,
            project_id: time_entry.project_id
          }
        }.as_json
      end
    end
  end
end
