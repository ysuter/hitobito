
#  Copyright (c) 2018, Grünliberale Partei Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

require 'digest/md5'

module Synchronize
  module Mailchimp
    class Client
      attr_reader :list_id, :count, :api

      def initialize(mailing_list, count = 50, debug = false)
        @list_id = mailing_list.mailchimp_list_id
        @count   = count

        @api = Gibbon::Request.new(api_key: mailing_list.mailchimp_api_key, debug: debug)
      end

      def members
        fetch_members
      end

      def delete(emails)
        execute_batch(emails) do |email|
          delete_operation(email)
        end
      end

      def subscribe(people)
        execute_batch(people) do |person|
          subscribe_operation(person)
        end
      end

      def delete_operation(email)
        subscriber_id = Digest::MD5.hexdigest(email.downcase)
        {
          method: 'DELETE',
          path: "lists/#{list_id}/members/#{subscriber_id}"
        }
      end

      def subscribe_operation(person)
        {
          method: 'POST',
          path: "lists/#{list_id}/members",
          body: subscriber_body(person).to_json
        }
      end

      private

      def fetch_members(list = [], offset = 0)
        params = { count: count, offset: offset }

        body = api.lists(list_id).members.retrieve(params: params).body.to_h
        body['members'].each do |entry|
          list << entry.slice('email_address', 'status').symbolize_keys
        end

        next_offset = offset + count
        if body['total_items'] > next_offset
          fetch_members(list, next_offset)
        else
          list
        end
      end

      def execute_batch(list)
        operations = list.collect do |item|
          yield(item).tap do |operation|
            logger.info "mailchimp: #{list_id}, op: #{operation[:method]}, item: #{item}"
            logger.info operation
          end
        end

        if operations.present?
          batch_id = api.batches.create(body: { operations: operations }).body.fetch('id')
          wait_for_finish(batch_id)
        end
      end

      def wait_for_finish(batch_id, count = 0)
        sleep count * count
        body = api.batches(batch_id).retrieve.body
        status = body.fetch('status')

        logger.info "batch #{batch_id}, status: #{status}"
        fail "Batch #{batch_id} did not finish in due time, last status: #{status}" if count > 10

        if status != 'finished'
          wait_for_finish(batch_id, count + 1)
        else
          body.slice( 'total_operations', 'finished_operations', 'errored_operations').tap do |result|
            logger.info result
          end
        end
      end

      def logger
        Rails.logger
      end

      def subscriber_body(person)
        {
          email_address: person.email,
          status: 'subscribed',
          merge_fields: {
            FNAME: person.first_name,
            LNAME: person.last_name
          }
        }
      end
    end
  end
end
