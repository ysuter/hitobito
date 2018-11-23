# encoding: utf-8

#  Copyright (c) 2012-2013, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

Airbrake.configure do |config|
  # if no host is given, use airbrake only in test mode
  config.project_key = ENV['RAILS_AIRBRAKE_API_KEY']
  config.project_id  = '42' # needs to be set to anything when using with errbit
  config.host        = ENV['RAILS_AIRBRAKE_HOST']

  config.environment = Rails.env
  config.ignore_environments = %w(development test)
end

Airbrake.add_filter do |notice|
  notice.ignore! if notice.stash[:exception].is_a?(ActionController::MethodNotAllowed)
  notice.ignore! if notice.stash[:exception].is_a?(ActionController::RoutingError)
  notice.ignore! if notice.stash[:exception].is_a?(ActionController::UnknownHttpMethod)

  %w(RAILS_DB_PASSWORD RAILS_MAIL_RETRIEVER_PASSWORD RAILS_AIRBRAKE_API_KEY
  RAILS_SECRET_TOKEN RAILS_MAIL_RETRIEVER_CONFIG RAILS_MAIL_DELIVERY_CONFIG).each do |param|
    if notice[:params][param]
      # filter out param
      notice[:params][param] = '[Filtered]'
    end
  end
end
