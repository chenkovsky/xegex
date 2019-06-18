module Xegex
  alias Expression = Regex::Expression::RegularExpression

  module Regex
    abstract class Expression(E)
      # 所有的expression合并起来，最终形成一个MatchingGroup
      class RegularExpression(E) < MatchingGroup(E)
        @auto : NFA(E)?

        getter(:auto) {
          build
        }

        def apply(tokens : Array(E))
          !find(tokens).nil?
        end

        def match?(tokens : Array(E))
          match = looking_at tokens
          !match.nil? && match.end_index == tokens.size
        end

        # 默认 /^a/.match("ba", 1) == nil
        def find(tokens : Array(E), start : Int32 = 0, has_start : Bool = (start == 0))
          (start..(tokens.size - auto.min_matching_length)).each do |i|
            match = looking_at(tokens, i, has_start && (i == start))
            return match if match
          end
          return nil
        end

        def looking_at(tokens : Array(E), start : Int32 = 0, has_start : Bool = (start == 0))
          auto.looking_at(tokens, start, has_start)
        end

        def match(tokens : Array(E))
          match = looking_at tokens
          return match if !match.nil? && match.end_index == tokens.size
          nil
        end

        def find_all(tokens : Array(E))
          results = Array(Match(E)).new
          start = 0
          while true
            match = find(tokens, start, start == 0)
            if match
              start = match.end_index
              if !match.empty?
                results << match
              end
            else
              break
            end
          end
          results
        end
      end
    end

    abstract class Match(E)
      @pairs : Array(Match::Group(E))

      protected def initialize
        @pairs = Array(Match::Group(E)).new
      end

      protected def initialize(match : Match(E))
        @pairs = match.pairs.map { |p| Group(E).new(p.expr, p.tokens) }
      end

      def <<(pair : Group(E))
        @pairs << pair
      end

      def concat(pairs)
        @pairs.concat(pairs)
      end

      def add(expr : Expression(E), token : E, pos : Int32)
        self << (Group(E).new(expr, token, pos))
      end

      delegate :empty?, to: @pairs

      def to_s(multi_line)
        sep = multi_line ? "\n" : ", "
        "[#{@pairs.map { |p| p.to_s }.join(sep)}]"
      end

      abstract def start_index : Int32
      abstract def end_index : Int32

      getter :pairs

      abstract def groups : Array(Group(E))
      abstract def entities : Array(E)

      delegate :length, to: entities

      def group(name : String)
        groups.each do |group|
          if group.expr.is_a?(Expression::NamedGroup(E))
            named_group = group.expr.as(Expression::NamedGroup(E))
            return group if named_group.name == name
          end
        end
        nil
      end

      def [](group_name : String)
        ret = group(group_name)
        raise KeyError.new if ret.nil?
        return ret
      end

      def []?(group_name : String)
        group(group_name)
      end

      def [](n : Int32)
        groups[n]
      end

      def []?(n : Int32)
        groups[n]?
      end

      class FinalMatch(E) < Match(E)
        @start_index : Int32
        @entities : Array(E)
        @groups : Array(Group(E))

        def initialize(m : Match(E))
          super(m)
          @start_index = m.start_index
          @entities = m.entities.map { |e| e }
          @groups = m.groups.map { |e| e }
        end

        def end_index
          start_index + entities.size
        end

        getter :start_index, :entities, :groups
      end

      class IntermediateMatch(E) < Match(E)
        def entities
          ret = Array(E).new
          pairs.each do |p|
            if p.expr.is_a? Expression::Base(E)
              ret.concat(p.entities)
            end
          end
          ret
        end

        def groups
          ret = Array(Group(E)).new
          pairs.each do |p|
            if p.expr.is_a?(Expression::MatchingGroup(E)) && !p.expr.is_a?(Expression::NonMatchingGroup(E))
              ret << p
            end
          end
          ret
        end

        def start_index
          pairs.each do |p|
            if p.expr.is_a? Expression::Base(E)
              return p.tokens[0].index
            end
          end
          return -1
        end

        def end_index
          pairs.reverse_each do |p|
            if p.expr.is_a?(Expression::Base(E))
              return p.tokens[0].index
            end
          end
          return -1
        end
      end

      class Group(E)
        class Token(E)
          @entity : E
          @index : Int32
          getter :entity, :index

          def initialize(@entity, @index)
          end

          delegate :to_s, to: @entity
        end

        @expr : Expression(E)
        @tokens : Array(Token(E))

        protected getter :expr, :tokens

        def initialize(expr : Expression(E), token : E, pos : Int32)
          @expr = expr
          @tokens = [Token(E).new(token, pos)]
        end

        def initialize(@expr, @tokens = Array(Token(E)).new)
        end

        protected def add_tokens(group : Group(E))
          @tokens.concat(group.tokens)
        end

        def entities
          @tokens.map { |x| x.entity }
        end

        def start_index
          ret = @tokens.min_of? { |t| t.index }
          ret.nil? ? -1 : ret
        end

        def end_index
          ret = @tokens.max_of? { |t| t.index }
          ret.nil? ? -1 : ret
        end

        def text
          @tokens.join(" ")
        end

        def count
          @tokens.size
        end

        def to_s
          "#{@expr.to_s}:'#{@tokens.map { |t| t.to_s }.join(" ")}'"
        end
      end
    end
  end
end
