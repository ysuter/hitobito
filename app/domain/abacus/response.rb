#  Copyright (c) 2018, Pfadibewegung Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

class Abacus::Response

  attr_reader :body, :action_response, :action, :request_id, :errors, :finished

  def initialize(response, action)
    @body = response.body.with_indifferent_access
    @action_response =  body["#{action}_response"]
    @action = action

    message = action_response.try(:[], :response_message)

    @request_id = message.try(:[], :request_id)
    @errors = evaluate_errors(message)
    @finished = message.try(:[], :is_finished) || errors.present? || action == :login
    self
  end

  private

  def evaluate_errors(message)
    runtime_errors || message_errors(message)
  end

  def runtime_errors
    return if body[:fault].blank?

    message = body[:fault][:detail].try(:[], :aba_connect_fault).try(:[], :message)
    error = body[:fault][:faultstring]

    [Abacus::Error.new(error, message)]
  end

  def message_errors(message)
    return if message.try(:[], :messages).blank?
    message[:messages].map do |_key, msg|
      Abacus::Error.new(msg[:text]) if msg['level'] == 'Error'
    end
  end


end
