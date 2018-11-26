#  Copyright (c) 2018, Pfadibewegung Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

class Abacus::Request
  include Abacus

  attr_reader :abacus_connection, :login_token
  delegate :connection, to: :abacus_connection

  def initialize(connection = nil)
    @abacus_connection = connection || Abacus::Connection.new
  end

  def ping
    response = connection.call(:ping, message: { echo: 'test' })
    Abacus::Response.new(response, :ping)
  end

  def login
    params = if login_token.present?
               { login_token: login_token }
             else
               { user_login: { user_name: username, password: password, mandant: mandant } }
             end

    response = call(:login, add_namespace(params), false)
    @login_token = response.action_response[:login_token]
    login_token.presence
  end

  def finished(request_id)
    return false if request_id.blank?
    params = { 'RequestID' => request_id }

    response = connection.call(:is_finished, message: add_namespace(params))

    Abacus::Response.new(response, :is_finished)
  end

  def find(key, value)
    params = { index: 3, operation: 'GREATER_EQUAL', key_fields: { } }

    find_params = [ find_param(:long_data, :customer_number, 0),
                    find_param(:string_data, key, value) ]

    params[:key_fields] = find_params.inject(&:deep_merge)
    params = { 'cus:FindParam' => add_namespace(params) }
    call(:find, params)
  end

  private

  def call(action, message = {}, authenticate = true)
    login if login_token.blank? && authenticate

    message.merge! login_params if authenticate
    response = connection.call(action, message: message)
    abacus_response = Abacus::Response.new(response, action)

    abacus_response.finished ? abacus_response : wait_for_request(abacus_response)
  end

  def wait_for_request(response)
    return response if response.request_id.blank?

    Timeout::timeout(1200) do
      loop do
        request = finished(response.request_id)
        return request if request.try(:finished?)
        sleep 2
      end
    end
  end

  def find_param(type, key, value)
    { type => value.to_s, attributes!: { type => { Name: key.to_s.camelize } } }
  end

  def login_params
    { 'cus:AbaConnectParam' =>  add_namespace({login: { login_token: login_token }, revision: 0 }) }
  end

end
