require "./expression"

module Xegex
  module Regex
    class NFA(E)
      @start : State::Terminus::Start(E)
      @end : State::Terminus::End(E)

      getter :start, :end

      def initialize(@start, @end)
      end

      def to_dot : String
        io = String::Builder.new
        io.puts "digraph {"
        queue = Deque(State(E)).new
        visited = Set(State(E)).new
        queue << @start
        visited << @start
        while !queue.empty?
          state = queue.shift
          state.edges.each do |e|
            io.puts "\"#{state.to_s}_#{state.object_id}\" -> \"#{e.dest.to_s}_#{e.dest.object_id}\" [label=#{e.expression.to_s.inspect}];"
            unless visited.includes? e.dest
              queue << e.dest
              visited << e.dest
            end
          end
          state.epsilons.each do |e|
            io.puts "\"#{state.to_s}_#{state.object_id}\" -> \"#{e.dest.to_s}_#{e.dest.object_id}\" [label=epsilon];"
            unless visited.includes? e.dest
              queue << e.dest
              visited << e.dest
            end
          end
        end
        io.puts "}"
        io.to_s
      end

      def initialize(expr : Expression(E))
        @start = State::Terminus::Start(E).new expr
        @end = State::Terminus::End(E).new expr
      end

      def apply(tokens : Array(E)) : Bool
        !evalute(tokens).nil?
      end

      def min_matching_length
        @start.min_matching_length
      end

      def looking_at(tokens : Array(E), start_index : Int32 = 0, has_start : Bool = (start_index == 0)) : Match::FinalMatch(E)?
        if tokens.size - start_index - min_matching_length < 0
          return nil
        end
        path = evaluate(tokens, start_index, has_start)
        if path.nil?
          return nil
        end
        p = path.not_nil!
        edges = Array(AbstractEdge(E)).new
        while p.state != @start
          edges << p.path.not_nil!
          p = p.prev.not_nil!
        end
        match = Match::IntermediateMatch(E).new
        build_match(tokens, nil, start_index, @start, edges, match)
        Match::FinalMatch(E).new match
      end

      private def build_match(tokens : Array(E),
                              expression : Expression(E)?,
                              index : Int32,
                              state : State(E),
                              edges : Array(AbstractEdge(E)),
                              match : Match::IntermediateMatch(E),
                              token_index = index,
                              edges_index = edges.size - 1) : Tuple(State(E), Int32, Int32, Int32)
        new_match = Match::IntermediateMatch(E).new
        while edges_index >= 0 && !(state.is_a?(State::Terminus::End(E)) && state.as(State::Terminus::End(E)).expression == expression)
          edge = edges[edges_index]
          edges_index -= 1
          if edge.is_a?(AbstractEdge::Edge(E)) && !edge.as(AbstractEdge::Edge(E)).expression.is_a?(Expression::Assertion(E))
            token = tokens[token_index]
            token_index += 1
            new_match.add(edge.as(AbstractEdge::Edge(E)).expression, token, index)
            index += 1
            state = edge.dest
          elsif state.is_a?(State::Terminus::Start(E))
            expr = state.as(State::Terminus::Start(E)).expression
            state, token_index, edges_index, index = build_match(tokens, expr, index, edge.dest, edges, new_match, token_index, edges_index)
            # assert(state instanceof EndState(T) && ((EndState(T))state).expression == expr);
          else
            state = edge.dest
          end
        end
        if !expression.nil? && (!new_match.empty? || expression.is_a?(Expression::MatchingGroup(E)))
          pair = Match::Group(E).new(expression)
          new_match.pairs.each do |p|
            if p.expr.is_a?(Expression::Base(E))
              pair.add_tokens p
            end
          end
          match << pair
        end
        match.concat new_match.pairs
        return state, token_index, edges_index, index
      end

      class Step(E)
        @state : State(E)
        @prev : Step(E)?
        @path : AbstractEdge(E)?

        protected getter :state, :prev, :path

        def initialize(@state, @prev = nil, @path = nil)
        end

        delegate :to_s, to: state
      end

      def expand_epsilons(steps : Array(Step(E)))
        states = Set.new(steps.map { |s| s.state })
        queue = Deque.new(steps)
        while !queue.empty?
          step = queue.shift
          step.state.epsilons.each do |edge|
            unless states.includes? edge.dest
              newstep = Step(E).new(edge.dest, step, edge)
              steps << newstep
              states << edge.dest
              queue << newstep
            end
          end
        end
        return steps
      end

      def expand_assertions(steps : Array(Step(E)),
                            newsteps : Array(Step(E)),
                            total_tokens : Int32,
                            consumed_tokens : Int32,
                            has_start : Bool)
        steps.each do |step|
          step.state.edges.each do |edge|
            if edge.expression.is_a? Expression::Assertion(E)
              assertion = edge.expression.as(Expression::Assertion(E))
              if assertion.apply(has_start, total_tokens, consumed_tokens)
                newsteps << Step(E).new(edge.dest, step, edge)
              end
            end
          end
        end
      end

      private def evaluate(tokens : Array(E), start_index : Int32, has_start : Bool = (start_index == 0))
        evaluate(tokens, [Step(E).new(start)], start_index, has_start)
      end

      # Evaluate the NFA against the list of tokens using the Thompson NFA algorithm
      # 其实就是 BFS 遍历
      private def evaluate(tokens : Array(E), steps : Array(Step(E)), start_index : Int32, has_start : Bool = (start_index == 0))
        total_tokens = tokens.size - start_index
        solution_tokens_left = total_tokens
        consumed_tokens = 0
        solution = nil
        while !steps.empty?
          expand_epsilons steps
          intermediate = steps.map { |s| s }
          newsteps = Array(Step(E)).new(steps.size * 2)
          while !intermediate.empty?
            intermediate.each do |step|
              # 检查是否满足
              next if step.state != self.end
              next if consumed_tokens == 0 # can't succeed if no tokens are consumed
              # we have reached the end
              next if total_tokens - consumed_tokens >= solution_tokens_left
              solution = step
              solution_tokens_left = total_tokens - consumed_tokens
            end

            # 检查是否是 ^ $
            # 如果是，自动将其加入steps
            newsteps.clear
            expand_assertions(intermediate, newsteps, total_tokens, consumed_tokens, has_start)
            expand_epsilons(newsteps)
            intermediate.clear
            intermediate.concat newsteps
            steps.concat newsteps
          end
          newsteps.clear
          unless consumed_tokens == total_tokens
            steps.each do |step|
              step.state.edges.each do |edge|
                if edge.apply(tokens[start_index + consumed_tokens])
                  newsteps << Step(E).new(edge.dest, step, edge)
                end
              end
            end
            consumed_tokens += 1
          end
          steps = newsteps
        end
        solution
      end

      class State(E)
        @edges : Array(AbstractEdge::Edge(E))
        @epsilons : Array(AbstractEdge::Epsilon(E))

        def initialize
          @edges = [] of AbstractEdge::Edge(E)
          @epsilons = [] of AbstractEdge::Epsilon(E)
        end

        protected getter :edges, :epsilons

        def connect(dest : State(E))
          @epsilons << AbstractEdge::Epsilon(E).new(dest)
        end

        def connect(dest : State(E), cost : Expression(E))
          @edges << AbstractEdge::Edge(E).new(dest, cost)
        end

        def to_s
          "#{self.class.name.split("::")[-1]}:#{@edges.size}"
        end

        class Terminus(E) < State(E)
          @expression : Expression(E)

          protected getter :expression

          def initialize(@expression)
            super()
          end

          def to_s
            "#{self.class.name.split("::")[-1]}(#{@expression.to_s}):#{edges.size}"
          end

          class Start(E) < Terminus(E)
            delegate :min_matching_length, to: @expression
          end

          class End(E) < Terminus(E)
          end
        end
      end

      abstract class AbstractEdge(E)
        @dest : State(E)

        protected getter :dest

        def initialize(@dest)
        end

        class Edge(E) < AbstractEdge(E)
          @expression : Expression(E)

          protected getter :expression

          def initialize(dest : State(E), base : Expression(E))
            super(dest)
            @expression = base
          end

          def to_s
            "(#{@expression.to_s}) -> #{dest.to_s}"
          end

          def apply(entity : E)
            return true if @expression.nil?
            return @expression.apply(entity)
          end
        end

        class Epsilon(E) < AbstractEdge(E)
          def to_s
            "(epsilon) -> #{dest.to_s}"
          end

          def apply(entity : E)
            return true
          end
        end
      end
    end
  end
end
