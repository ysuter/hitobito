# encoding: utf-8

#  Copyright (c) 2014, hitobito AG. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

class CreateTranslationTables < ActiveRecord::Migration[4.2]
  def up
    CustomContent.create_translation_table!(
      { label: :string,
        subject: :string,
        body: :text },
      { migrate_data: true })

    # temporary index name too long, drop and recreate
    CustomContent.globalize_migrator.drop_translations_index
    CustomContent.globalize_migrator.create_translations_index(uniq_index: true)
    remove_column :custom_contents, :label
    remove_column :custom_contents, :subject
    remove_column :custom_contents, :body

    Event::Kind.create_translation_table!(
      { label: :string,
        short_name: :string },
      { migrate_data: true }
    )
    remove_column :event_kinds, :label
    remove_column :event_kinds, :short_name, limit: 20

    LabelFormat.create_translation_table!(
      { name: :string },
      { migrate_data: true }
    )
    remove_column :label_formats, :name

    QualificationKind.create_translation_table!(
      { label: :string,
        description: { type: :string, limit: 1023 } },
      { migrate_data: true }
    )
    # temporary index name too long, drop and recreate
    QualificationKind.globalize_migrator.drop_translations_index
    QualificationKind.globalize_migrator.create_translations_index(uniq_index: true)
    remove_column :qualification_kinds, :label
    remove_column :qualification_kinds, :description
  end

  def down
    add_column :qualification_kinds, :description, :string, limit: 1023
    add_column :qualification_kinds, :label, :string
    QualificationKind.drop_translation_table! migrate_data: true

    add_column :label_formats, :name, :string
    LabelFormat.drop_translation_table! migrate_data: true

    add_column :event_kinds, :short_name, :string
    add_column :event_kinds, :label, :string
    Event::Kind.drop_translation_table! migrate_data: true

    add_column :custom_contents, :label, :string
    add_column :custom_contents, :subject, :string
    add_column :custom_contents, :body, :text
    CustomContent.drop_translation_table! migrate_data: true
  end
end
