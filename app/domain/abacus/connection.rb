#  Copyright (c) 2018, Pfadibewegung Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

class Abacus::Connection
  include Abacus

  attr_reader :connection

  def initialize
    return false if Settings.abacus.blank?
    @connection = connect_to_server

    Abacus::Request.new(self).ping # Test the given connection
    self
  end

  private

  def connect_to_server
    Savon.client(wsdl: '/home/jbinder/documentation/abacus/kunden_2017/Customer.wsdl',
                 pretty_print_xml: Rails.env.development?,
                 log: Rails.env.development?,
                 endpoint: "#{host}/abaconnect/services/Customer_2017_00",
                 namespace_identifier: :cus,
                 namespaces: { 'xmlns:abac' => 'http://www.abacus.ch/abaconnect/2007.10/core/AbaConnectTypes',
                               'xmlns:cus' => 'http://www.abacus.ch/abaconnect/2017.00/debi/Customer' })
  end

end
