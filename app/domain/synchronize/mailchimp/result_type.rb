module Synchronize
  module Mailchimp
    class ResultType < ActiveRecord::Type::Value

      # to db
      def serialize(result)
        result ? result.data.to_json : nil
      end

      # from user or db
      def cast(value)
        case value
        when String then Result.new(JSON.parse(value))
        when Hash then Result.new(value)
        when Result then value
        else Result.new
        end
      end

    end
  end
end
