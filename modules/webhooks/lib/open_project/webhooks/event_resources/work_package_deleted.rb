require_relative "base"

module OpenProject::Webhooks::EventResources
  class WorkPackageDeleted < Base
    class << self
      def notification_names
        [
          OpenProject::Events::WORK_PACKAGE_DESTROYED
        ]
      end

      def available_actions
        %i(deleted)
      end

      def resource_name
        I18n.t :label_work_package_plural
      end

      def prefix_key
        "work_package"
      end

      protected

      def handle_notification(payload, _event_name)
        work_package = payload[:work_package]
        event_name = prefixed_event_name(:deleted)
        body = deleted_payload(event_name, work_package, payload[:actor])

        active_webhooks.with_event_name(event_name).pluck(:id).each do |id|
          SerializedWebhookJob.perform_later(id, work_package.project_id, event_name, body)
        end
      end

      def deleted_payload(event_name, work_package, actor)
        payload = {
          action: event_name,
          work_package: {
            _type: "WorkPackage",
            id: work_package.id,
            subject: work_package.subject,
            project_id: work_package.project_id
          }
        }

        if actor
          payload[:actor] = User.system.run_given do
            ::API::V3::Users::UserRepresenter.create(actor, current_user: User.current).as_json
          end
        end

        payload.as_json
      end
    end
  end
end
