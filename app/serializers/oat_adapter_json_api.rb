#  Copyright (c) 2018, CEVI Regionalverband ZH-SH-GL. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

class OatAdapterJsonApi < Oat::Adapters::JsonAPI

  # Overwrite default type method to use correct pluralization
  def type(*types)
    @root_name = types.first.to_s.pluralize.to_sym
  end

end
