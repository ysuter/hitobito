module Synchronize
  module Mailchimp
    class Result

      STATE_BADGES = {
        unchanged: :success,
        success: :success,
        partial: :info,
        failed: :warning
      }.freeze

      attr_reader :data

      def initialize(data = {})
        @data = data.deep_symbolize_keys
      end

      def subscribed=(response)
        @data[:subscribed] = extract(response) if response
      end

      def deleted=(response)
        @data[:deleted] = extract(response) if response
      end

      def unchanged?
        @data.empty?
      end

      def success?
        @data.values.all? { |val| val.key?(:success) }
      end

      def partial?
        @data.values.any? { |val| val.key?(:partial) }
      end

      def failed?
        @data.values.all? { |val| val.key?(:errors) }
      end

      def badge_info
        state = STATE_BADGES.keys.find { |key| send("#{key}?") }
        [state, STATE_BADGES[state]]
      end

      private

      def extract(response)
        total, succeeded, failed = response
          .slice('total_operations',
                 'finished_operations',
                 'errored_operations').values.collect(&:to_i)

        if total == succeeded
          { success: total }
        elsif succeeded.positive? && failed.positive?
          { partial: [succeeded, failed] }
        else
          { failed: failed }
        end
      end
    end
  end
end
