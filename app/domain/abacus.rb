#  Copyright (c) 2018, Pfadibewegung Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

module Abacus

  def add_namespace(message, namespace = :abac, deep = true)
    message.map do |k, v|
      if k.to_sym == :attributes! # Do not add namespace to attributes
        next [k, add_namespace(v, namespace, false)]
      end

      v = v.is_a?(Hash) && deep ? add_namespace(v, namespace) : v
      k = "#{namespace}:#{k.to_s.camelcase}"
      [k, v]
    end.to_h
  end

  %i(username password mandant host).each do |setting|
    define_method(setting) do
      Settings.abacus.public_send(setting).to_s
    end
  end
end
