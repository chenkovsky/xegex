module Xegex
  module Regex
    abstract class Expression(E)
      abstract def build : NFA(E)
      abstract def min_matching_length : Int32

      def ==(other : Expression(E))
        to_s == other.to_s
      end

      class MatchingGroup(E) < Expression(E)
        @expressions : Array(Expression(E))

        getter :expressions

        def apply(entity : E) : Bool
          raise "UnsupportedOperation"
        end

        def initialize(@expressions)
        end

        protected def subexp_str
          "#{@expressions.map { |e| e.to_s }.join(" ")}"
        end

        def to_s
          "(#{subexp_str})"
        end

        def build
          auto = NFA(E).new(self)
          last = @expressions.reduce(auto.start) do |prev, e|
            sub = e.build
            connector = NFA::State(E).new
            prev.connect(connector)
            connector.connect(sub.start)
            sub.end
          end
          last.connect(auto.end)
          auto
        end

        def min_matching_length
          @expressions.reduce(0) { |acc, e| acc += e.min_matching_length }
        end
      end

      class NamedGroup(E) < MatchingGroup(E)
        @name : String

        def initialize(@name, expressions)
          super(expressions)
        end

        def to_s
          "(#{@name}>:#{subexp_str})"
        end

        getter :name
      end

      class NonMatchingGroup(E) < MatchingGroup(E)
        def to_s
          "(?:#{subexp_str})"
        end
      end

      class Or(E) < Expression(E)
        @expr1 : Expression(E)
        @expr2 : Expression(E)

        def initialize(@expr1, @expr2)
        end

        def apply(entity : E)
          return true
        end

        def to_s
          "#{@expr1.to_s} | #{@expr2.to_s}"
        end

        def build
          auto = NFA(E).new(self)
          sub1 = @expr1.build
          sub2 = @expr2.build
          auto.start.connect(sub1.start)
          auto.start.connect(sub2.start)
          sub1.end.connect(auto.end)
          sub2.end.connect(auto.end)
          auto
        end

        def min_matching_length
          [@expr1.min_matching_length, @expr2.min_matching_length].min
        end
      end

      class Star(E) < Expression(E)
        @expr : Expression(E)
        getter :expr

        def initialize(@expr)
        end

        def apply(entity : E)
          @expr.apply(entity)
        end

        def to_s
          "#{@expr.to_s}*"
        end

        def build
          auto = NFA.new(self)
          sub = @expr.build
          sub.end.connect(sub.start)
          auto.start.connect(sub.start)
          sub.end.connect(auto.end)
          auto.start.connect(auto.end)
          auto
        end

        def min_matching_length
          0
        end
      end

      class Plus(E) < Expression(E)
        @expr : Expression(E)
        getter :expr

        def initialize(@expr)
        end

        def apply(entity : E)
          @expr.apply(entity)
        end

        def to_s
          "#{@expr.to_s}+"
        end

        def build
          auto = NFA(E).new(self)
          sub = @expr.build
          sub.end.connect(sub.start)
          auto.start.connect(sub.start)
          sub.end.connect(auto.end)
          auto
        end

        def min_matching_length
          @expr.min_matching_length
        end
      end

      class Option(E) < Expression(E)
        @expr : Expression(E)
        getter :expr

        def initialize(@expr)
        end

        def apply(entity : E)
          @expr.apply(entity)
        end

        def to_s
          "#{@expr.to_s}?"
        end

        def build
          auto = NFA(E).new self
          sub = @expr.build
          auto.start.connect(sub.start)
          sub.end.connect(auto.end)
          auto.start.connect(auto.end)
          auto
        end

        def min_matching_length
          0
        end
      end

      class MinMax(E) < Expression(E)
        @expr : Expression(E)
        @min_occurrences : Int32
        @max_occurrences : Int32

        def initialize(@expr, @min_occurrences, @max_occurrences)
          if @min_occurrences < 0 || @max_occurrences < 1
            raise Exception::IllegalArgumentException.new("minOccurrences must be >= 0 and maxOccurrences must be >= 1: #{@min_occurrences}, #{@max_occurrences}")
          end
          if @min_occurrences > @max_occurrences
            raise Exception::IllegalArgumentException.new("minOccurrences must be <= maxOccurrences: #{@min_occurrences} > #{@max_occurrences}")
          end
        end

        def apply(entity : E)
          @expr.apply(entity)
        end

        def to_s
          "#{@expr.to_s}{#{@min_occurrences}, #{@max_occurrences}}"
        end

        def build
          auto = NFA(E).new(self)
          sub_autos = (0...@max_occurrences).map { @expr.build }
          auto.start.connect(sub_autos[0].start)
          sub_autos.each_with_index do |sub, i|
            if i >= @min_occurrences - 1
              sub.end.connect(auto.end)
            end
            if i < sub_autos.size - 1
              sub.end.connect(sub_autos[i + 1].start)
            end
          end
          if @min_occurrences == 0
            auto.start.connect(auto.end)
          end
          auto
        end

        def min_matching_length
          @min_occurrences * @expr.min_matching_length
        end
      end

      abstract class Base(E) < Expression(E)
        abstract def apply(e : E) : Bool
        abstract def source : String

        def build
          auto = NFA(E).new(self)
          auto.start.connect(auto.end, self)
          auto
        end

        def min_matching_length
          1
        end

        class Lambda(E) < Base(E)
          @block : E -> Bool
          @source : String
          getter :source

          def initialize(@source, &@block : E -> Bool)
          end

          def apply(e : E) : Bool
            @block.call(e)
          end

          def to_s
            "<#{@source}>"
          end
        end
      end

      abstract class Assertion(E) < Expression(E)
        def apply(entity : E)
          false
        end

        abstract def apply(has_start : Bool, total_tokens : Int32, consumed_tokens : Int32) : Bool

        def build
          auto = NFA.new(self)
          auto.start.connect(auto.end, self)
          auto
        end

        def min_matching_length
          0
        end
      end

      class Start(E) < Assertion(E)
        def apply(has_start : Bool, total_tokens : Int32, consumed_tokens : Int32)
          has_start && consumed_tokens == 0
        end

        def to_s
          "^"
        end
      end

      class End(E) < Assertion(E)
        def apply(has_start : Bool, total_tokens : Int32, consumed_tokens : Int32)
          total_tokens == consumed_tokens
        end

        def to_s
          "$"
        end
      end
    end
  end
end
