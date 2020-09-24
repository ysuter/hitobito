# encoding: utf-8

#  Copyright (c) 2019, hitobito AG. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

module TagListsHelper

  def available_tags_checkboxes(tags)
    safe_join(tags.map do |tag, count|
      content_tag(:div, class: 'control-group  available-tag') do
        tag_checkbox(tag, count)
      end
    end, '')
  end

  def format_tag_category(category)
    case category
    when :other
      t('.category_other')
    when :t_email
      t('.email')
    else
      category
    end
  end

  def format_tag_value(tag, category)
    ttv = translatable_tag_values
    category = category.to_sym
    tag = tag.name_without_category
    if ttv[category]&.include?(tag)
      t(".#{category}.#{tag}")
    else
      tag
    end
  end

  private

  def translatable_tag_values
    { t_email: %w(primary-invalid additional-invalid) }
  end

  def tag_checkbox(tag, count)
    label_tag(nil, class: 'checkbox ') do
      out = check_box_tag("tags[]", tag.name, false)
      out << tag
      out << content_tag(:div, class: 'role-count') do
        count.to_s
      end
      out.html_safe
    end
  end
end
