require "./exception"

module Xegex
  module Regex
    class Expression(E)
      def self.compile(string : String, &factory : String -> Base(E)) : Xegex::Expression(E)
        toks = self.tokenize(string, factory)
        Xegex::Expression(E).new toks
      end

      # 读取token
      private def self.read_token(remaining : Array(Char), start = 0)
        c = remaining[start]
        _end = case c
               when '<'
                 index_of_close(remaining, start, '<', '>')
               when '['
                 index_of_close(remaining, start, '[', ']')
               else
                 raise Exception::IllegalStateException.new("Unexpect char: #{c.inspect}")
               end
        if _end == -1
          raise Exception::TokenizationRegexException.new("bad token. Non-matching brackets (<> or []): #{start}:\"#{remaining[start..-1]}\"")
        end
        String.build { |io| (start.._end).each { |i| io << remaining[i] } }
      end

      private WhitespacePattern = /\s+/
      private UnaryPattern      = /[\*\?\+]/
      private MinMaxPattern     = /\{(\d+),(\d+)\}/
      private BinaryPattern     = /[\|]/
      private NamedPattern      = /<(\w*)>\:(.*)/
      private UnnamedPattern    = /\?\:(.*)/

      # 将表达式转成Expression数组
      def self.tokenize(string : String, factory : String -> Base(E)) : Array(Expression(E))
        expressions = Array(Expression(E)).new
        tokens = Array(String).new
        stack = ' '
        start : Int32 = 0
        chars = string.chars
        while start < chars.size
          if !" \t\n\r".index(chars[start]).nil?
            while start < chars.size && !" \t\n\r".index(chars[start]).nil?
              start += 1
            end
            next
          end
          c = chars[start]
          if ['(', '<', '[', '$', '^'].includes? c
            if chars[start] == '('
              end_ = index_of_close(chars, start, '(', ')')
              if end_ == -1
                raise Exception::TokenizationRegexException.new("unclosed parenthesis: #{start}:\"#{string[start..-1]}\"")
              end
              group = String.build { |io| ((start + 1)...end_).each { |i| io << chars[i] } }
              start = end_ + 1
              if (matcher = NamedPattern.match(group)) && matcher.begin == 0
                group_name = matcher[1]
                group = matcher[2]
                group_expressions = tokenize(group, factory)
                expressions << NamedGroup(E).new(group_name, group_expressions)
              elsif (matcher = UnnamedPattern.match(group)) && matcher.begin == 0
                group = matcher[1]
                group_expressions = tokenize(group, factory)
                expressions << NonMatchingGroup(E).new(group_expressions)
              else
                group_expressions = tokenize(group, factory)
                expressions << MatchingGroup(E).new(group_expressions)
              end
            elsif ['<', '['].includes? c
              token = read_token(chars, start)
              begin
                token_inside = token[1...-1]
                base = factory.call(token_inside)
                expressions << base
                start += token.size
              rescue e
                raise Exception::TokenizationRegexException.new("error parsing token: #{token}. #{e}", e)
              end
            elsif '^' == c
              expressions << Start(E).new
              start += 1
            elsif '$' == c
              expressions << End(E).new
              start += 1
            end
            if '|' == stack
              begin
                stack = ' '
                if expressions.size < 2
                  raise Exception::IllegalStateException.new("OR operator is applied to fewer than 2 elements.")
                end
                expr1 = expressions.pop
                expr2 = expressions.pop
                expressions << Or(E).new(expr1, expr2)
              rescue e
                raise Exception::TokenizationRegexException.new("error parsing OR (|) operator.", e)
              end
            end
          elsif !"*?+".index(chars[start]).nil?
            operator = chars[start]
            base = expressions.pop
            expr = case operator
                   when '?'
                     Option(E).new(base)
                   when '*'
                     Star(E).new(base)
                   when '+'
                     Plus(E).new(base)
                   else
                     raise Exception::IllegalStateException.new
                   end
            expressions << expr
            start += 1
          elsif chars[start] == '{' && (matcher = MinMaxPattern.match(string, start)) && matcher.begin == start
            min_occurrences = matcher[1].to_i
            max_occurrences = matcher[2].to_i
            base = expressions.pop
            expr = MinMax(E).new(base, min_occurrences, max_occurrences)
            expressions << expr
            start = matcher.end.as(Int32)
          elsif chars[start] == '|'
            tokens << "|"
            stack = '|'
            start += 1
          else
            raise Exception::TokenizationRegexException.new("unknown symbol: #{string[start..-1]}")
          end
        end
        if stack == '|'
          raise Exception::TokenizationRegexException.new("OR remains on the stack.")
        end
        expressions
      end

      # 找到匹配的括号，@TODO 注意escape
      private def self.index_of_close(string : Array(Char), start : Int32, open : Char, close : Char) : Int32
        start -= 1
        count = 0
        while true
          start += 1
          if start >= string.size
            return -1
          end
          c = string[start]
          if c == open
            count += 1
          elsif c == close
            count -= 1
          end
          break if count == 0
        end
        return start
      end
    end
  end
end
