module Xegex
  module Logic
    # 逻辑中间表达式，逻辑表达式分词后的中间结果
    abstract class Expression(E)
      # 获得所有的args
      def self.args(ret = Array(String).new) : Array(String)
        case self
        when Op::Bin(E)
          bin = self.as(Op::Bin(E))
          bin.left.args(ret)
          bin.right.args(ret)
        when Pred(E)
          ret << (self.as(Pred(E)).description)
        end
        ret
      end

      # 匹配entity的略偶记表达式
      abstract class Apply(E) < Expression(E)
        # 该表达式是否能够匹配到该entity上
        abstract def apply(entity : E) : Bool

        # just make compiler happy
        class Nonsense(E) < Apply(E)
          def apply(entity : E)
            true
          end

          def to_s(io)
            io << "<Nonsense>"
          end

          def inspect(io)
            io << "<Nonsense>"
          end
        end

        # 操作符
        abstract class Op(E) < Apply(E)
          # 该操作符的优先级是否比 that 大
          def preceeds(that : Op)
            precedence < that.precedence
          end

          # 返回 该操作符的优先级
          abstract def precedence : Int32

          # 只取一个参数的操作，比如取反
          abstract class Mon(E) < Op(E)
            @sub : Apply(E)

            protected property :sub

            def initialize(@sub)
            end

            def description(symbol : String)
              "#{symbol}(#{sub})"
            end

            # 取反操作
            class Not(E) < Mon(E)
              def to_s(io)
                io << description "!"
              end

              def apply(entity : E)
                !sub.apply(entity)
              end

              def precedence
                0
              end
            end
          end

          # 二元操作符
          abstract class Bin(E) < Op(E)
            @left : Apply(E)
            @right : Apply(E)

            protected property :left, :right

            def initialize(@left, @right)
            end

            def description(symbol : String)
              (left.nil? || right.nil?) ? symbol : "(#{left.to_s} #{symbol} #{right.to_s})"
            end

            # and 操作符
            class And(E) < Bin(E)
              def to_s(io)
                io << (description "&")
              end

              def apply(entity : E)
                return left.apply(entity) && right.apply(entity)
              end

              def precedence
                1
              end
            end

            # or 操作符
            class Or(E) < Bin(E)
              def to_s(io)
                io << (description "|")
              end

              def apply(entity : E)
                left.apply(entity) || right.apply(entity)
              end

              def precedence
                2
              end
            end
          end
        end

        # atomic的bool表达式
        abstract class Arg(E) < Apply(E)
          # 在给定entity上面匹配
          class Pred(E) < Arg(E)
            @description : String
            @block : E -> Bool

            def initialize(@description, &@block : E -> Bool)
            end

            def apply(entity : E) : Bool
              @block.call(entity)
            end

            getter :description

            delegate :to_s, to: :description
          end

          # 给定bool值
          class Value(E) < Arg(E)
            @value : Bool

            def initialize(@value)
            end

            def apply(entity : E)
              apply
            end

            def apply
              value
            end

            delegate :to_s, to: @value
          end
        end
      end

      class Paren(E) < Expression(E)
        class L(E) < Paren(E)
          def to_s(io)
            io << '('
          end
        end

        class R(E) < Paren(E)
          def to_s(io)
            io << ')'
          end
        end
      end

      alias Pred = Apply::Arg::Pred
    end
  end
end
