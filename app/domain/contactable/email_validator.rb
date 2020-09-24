# frozen_string_literal: true

module Contactable
  class EmailValidator

    INVALID_PRIMARY_TAG='t_email:primary-invalid'.freeze
    INVALID_ADDITIONAL_TAG='t_email:additional-invalid'.freeze

    def validate_people
      Person.all.find_each do |p|
        if invalid?(p.email)
          tag_invalid!(p)
        end
      end
    end

    private

    def invalid?(email)
      !Truemail.valid?(email)
    end

    def tag_invalid!(person)
      ActsAsTaggableOn::Tagging
        .create!(taggable: person,
                 hitobito_tooltip: person.email,
                 context: :tags,
                 tag: invalid_email_tag)
    end

    def invalid_email_tag
      ActsAsTaggableOn::Tag.find_or_create_by!(name: INVALID_PRIMARY_TAG)
    end
  end
end
