#  Copyright (c) 2018, Grünliberale Partei Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

require 'digest/md5'

module Synchronize
  module Mailchimp
    class Synchronizator

      attr_reader :mailing_list, :result

      def initialize(mailing_list)
        @mailing_list = mailing_list
        @result = Result.new
      end

      def call
        rescued do
          # subscribe_missing_people
          # archive_obsolete_people


          create_missing_tags
          update_people_tags
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

      def client
        @client ||= Client.new(mailing_list)
      end

      private

      def rescued
        mailing_list.update(mailchimp_syncing: true)
        yield
        mailing_list.update(mailchimp_last_synced_at: Time.zone.now)
      rescue => exception
        result.exception = exception
      ensure
        mailing_list.update(mailchimp_syncing: false, mailchimp_result: result)
      end

      def subscribe_missing_people
        result.subscribed = client.subscribe(missing_people)
      end

      def archive_obsolete_people
        result.deleted = client.delete(obsolete_emails)
      end

      def update_people_tags
        result.tags = client.update_segments(tag_changes)
      end

      def create_missing_tags
        missing  = local_tags.keys - client.fetch_segments.collect { |s| s[:name] }
        client.create_segments(missing)
      end

      def local_tags
        @local_tags ||= people.each_with_object({}) do |person, hash|
          next unless person.email

          if person.gender.present?
            hash[person.gender_label] ||= []
            hash[person.gender_label] << person.email
          end

          person.tags.each do |tag|
            value = tag.name
            hash[value] ||= []
            hash[value] << person.email
          end
        end
      end

      def tag_changes
        segments = client.fetch_segments.index_by { |s| s[:name] }
        members  = client.fetch_members

        local_tags.collect do |tag, emails|
          next if emails.sort == tagged_emails(members, tag).sort

          [segments.dig(tag, :id), emails]
        end.compact
      end

      def tagged_emails(members, tag)
        members.select { |m| m[:tags].include?(tag) }.collect { |m| m[:email] }
      end

      def build_tag_diff(person, remote_tags)
        missing + obsolete
      end

      def people
        @people ||= mailing_list.people.includes(:tags).unscope(:select)
      end

      # We return ALL emails, even when they have unsubscribed
      def mailchimp_emails
        members.collect { |member| member[:email_address] }
      end

      def members
        @members ||= client.members
      end

    end
  end
end
