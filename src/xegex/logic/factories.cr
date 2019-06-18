module Xegex
  module Logic
    # 各种产生 Pred 的 factory
    module Factory
      # 字符串比较
      StringMatch = ->(token : String) {
        str = token[1...-1]
        Expression::Pred(String).new token do |entity|
          entity == str
        end
      }
    end
  end
end
