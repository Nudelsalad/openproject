#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

class WebhookJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  attr_reader :webhook_id, :event_name

  good_job_control_concurrency_with(
    perform_limit: 1,
    key: -> { "WebhookDelivery-#{arguments.first}-#{concurrency_project_id}" }
  )

  retry_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError,
           wait: 5.seconds,
           attempts: :unlimited

  # Delivery failures which are likely to be temporary are retried with backoff.
  retry_on Timeout::Error,
           Faraday::TimeoutError,
           Webhooks::Outgoing::RequestWebhookService::TransientRequestError,
           wait: :polynomially_longer,
           attempts: 5

  def perform(webhook_id, event_name)
    @webhook_id = webhook_id
    @event_name = event_name
  end

  def webhook
    @webhook ||= Webhooks::Webhook.find(webhook_id)
  end

  private

  def concurrency_project_id
    resource_or_project_id = arguments.second
    resource_or_project_id.respond_to?(:project_id) ? resource_or_project_id.project_id : resource_or_project_id
  end
end
