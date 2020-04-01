#  Copyright (c) 2018, Grünliberale Partei Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

require 'digest/md5'

module Synchronize
  module Mailchimp
    class Synchronizator
      attr_reader :mailing_list, :result

      class_attribute :merge_fields, :member_fields
      self.member_fields = []

      self.merge_fields = [
        [ 'Gender', 'dropdown', { choices: %w(m w) },  ->(p) { p.gender } ]
      ]

      def initialize(mailing_list, rescued: true)
        @mailing_list = mailing_list
        @result = Result.new
        @rescued = rescued
      end

      def call
        rescued do
          create_missing_merge_fields
          create_missing_tags

          subscribe_missing_people
          archive_obsolete_people

          update_people_tags
          update_changed_people

          delete_obsolete_segments
        end
      end

      def missing_people
        people.reject do |person|
          mailchimp_emails.include?(person.email) || person.email.blank?
        end
      end

      def obsolete_emails
        mailchimp_emails - people.collect(&:email)
      end

      # TODO does not work for locally removed tags
      def changed_tags
        segments = client.fetch_segments.index_by { |t| t[:name] }

        local_tags.collect do |tag, emails|
          next if emails.sort == remote_tags.fetch(tag, []).sort

          [segments.dig(tag, :id), emails]
        end.compact
      end

      def changed_people
        @changed_people ||= people.select do |person|
          member = members_by_email[person.email]
          member.deep_merge(client.subscriber_body(person)) != member if member
        end
      end

      def client
        @client ||= Client.new(mailing_list, member_fields: member_fields, merge_fields: merge_fields)
      end

      private

      def rescued
        mailing_list.update(mailchimp_syncing: true)
        yield
        mailing_list.update(mailchimp_last_synced_at: Time.zone.now)
      rescue => exception
        result.exception = exception
        raise exception unless rescued?
      ensure
        mailing_list.update(mailchimp_syncing: false, mailchimp_result: result)
      end

      def subscribe_missing_people
        result.subscribed = client.subscribe(missing_people)
      end

      def archive_obsolete_people
        result.deleted = client.delete(obsolete_emails)
      end

      def delete_obsolete_segments
        result.segments = client.delete_segments(obsolete_segments)
      end

      def update_people_tags
        result.tags = client.update_segments(changed_tags)
      end

      def update_changed_people
        result.updates = client.update_members(changed_people) if changed_people.present?
      end

      def create_missing_merge_fields
        tags = client.fetch_merge_fields.collect { |field| field[:tag] }
        missing = merge_fields.reject { |name, _, _| tags.include?(name.upcase) }
        result.merge_fields = client.create_merge_fields(missing)
      end

      def create_missing_tags
        missing = local_tags.keys - client.fetch_segments.collect { |s| s[:name] }
        client.create_segments(missing)
      end

      def delete_obsolete_segments
        missing = client.fetch_segments.reject do |s|
          local_tags.keys.include?(s[:name])
        end.collect { |s| s[:id] }
        client.delete_segments(missing)
      end

      def local_tags
        @local_tags ||= people.each_with_object({}) do |person, hash|
          next unless person.email

          person.tags.each do |tag|
            value = tag.name
            hash[value] ||= []
            hash[value] << person.email
          end
        end
      end

      def remote_tags
        @remote_tags ||= members.each_with_object({}) do |member, hash|
          member[:tags].each do |tag|
            hash[tag[:name]] ||= []
            hash[tag[:name]] << member[:email_address]
          end
        end
      end

      def people
        @people ||= mailing_list.people.includes(:tags).unscope(:select)
      end

      # We return ALL emails, even when they have unsubscribed
      def mailchimp_emails
        members.collect { |member| member[:email_address] }
      end

      def members
        @members ||= client.fetch_members
      end

      def members_by_email
        @members_by_email ||= members.index_by { |m| m[:email_address] }
      end

      def rescued?
        @rescued
      end

    end
  end
end
