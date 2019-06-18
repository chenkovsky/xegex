require "./expression"

module Xegex
  module Regex
    # 各种产生 Base 的 factory
    module Factory
      # 字符串比较
      WordMatch = ->(token : String) {
        Expression::Base::Lambda(String).new token do |entity|
          entity == token
        end
      }

      CharMatch = ->(token : String) {
        Expression::Base::Lambda(Char).new token do |entity|
          entity.to_s == token
        end
      }
    end
  end
end
