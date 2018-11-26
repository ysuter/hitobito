#  Copyright (c) 2018, Pfadibewegung Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

class AbacusConnection

  attr_reader :connection, :login_token

  def initialize
    return false if Settings.abacus.blank?
    @connection = connect_to_server
    
    ping # Test the given connection
  end

  def ping
    connection.call(:ping, message: { echo: 'test' }).body
  rescue
    raise 'Unable to access Host'
  end

  def login
    params = if login_token.present?
               { login_token: login_token }
             else
               { user_login: { user_name: username, password: password, mandant: mandant } }
             end

    response = call(:login, add_namespace(params), false).body
    @login_token = response[:login_response][:login_token]
    login_token.presence
  end

  def call(action, message = {}, authenticate = true)
    login if login_token.blank? && authenticate
    message.merge! login_params if authenticate
    connection.call(action, message: message)
  end

  def find
    params = { index: 1, operation: 'EQUAL', key_fields: { } }
    params[:key_fields].merge!({ long_data: '1', attributes!: { long_data: { name: 'CustomerName' } }})
    params = { 'cus:FindParam' => add_namespace(params) }
    call(:find, params)
  end

  private

  def login_params
    { 'cus:AbaConnectParam' =>  add_namespace({login: { login_token: login_token }, revision: 0 }) }
  end

  def connect_to_server
    Savon.client(wsdl: '/home/jbinder/documentation/abacus/kunden_2017/Customer.wsdl',
                 pretty_print_xml: Rails.env.development?,
                 log: Rails.env.development?,
                 endpoint: "#{host}/abaconnect/services/Customer_2017_00",
                 namespace_identifier: :cus,
                 namespaces: { 'xmlns:abac' => 'http://www.abacus.ch/abaconnect/2007.10/core/AbaConnectTypes',
                               'xmlns:cus' => 'http://www.abacus.ch/abaconnect/2017.00/debi/Customer' })
  end

  def add_namespace(message, namespace = :abac)
    message.map do |k, v|
      v = v.is_a?(Hash) ? add_namespace(v, namespace) : v
      ["#{namespace}:#{k.to_s.camelcase}", v]
    end.to_h
  end

  %i(username password mandant host).each do |setting|
    define_method(setting) do
      Settings.abacus.public_send(setting).to_s
    end
  end

end
