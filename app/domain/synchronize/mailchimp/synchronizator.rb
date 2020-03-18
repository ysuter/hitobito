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
        subscribe_missing
        delete_obsolete
      rescue => e
        result.exception = e
      ensure
        update_list
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

      def update_list
        mailing_list.update(
          mailchimp_last_synced_at: Time.zone.now,
          mailchimp_result: result
        )
      end

      def subscribe_missing
        result.subscribed = client.subscribe(missing_people)
      end

      def delete_obsolete
        result.deleted = client.delete(obsolete_emails)
      end

      def people
        @people ||= mailing_list.people
      end

      # We return ALL emails, even when they have unsubscribed
      def mailchimp_emails
        @mailchimp_emails ||= client.members.collect do |member|
          member[:email_address]
        end
      end
    end
  end
end
