require "./expression"
require "./exception"

module Xegex
  module Logic
    # 将表达式转成 逻辑表达式
    abstract class Expression(E)
      private DoubleQuoteStringLiteralRegex = /"(?:[^\\"]|\\.)*"/
      private SingleQuoteStringLiteralRegex = /'(?:[^\\']|\\.)*'/
      private RegexLiteralRegex             = /\/(?:[^\/\\]|\\.)*\//
      private LiteralPatterns               = [DoubleQuoteStringLiteralRegex, SingleQuoteStringLiteralRegex, RegexLiteralRegex]

      def self.compile(string : String, &factory : String -> Expression::Pred(E)) : Expression(E)
        expressions = self.tokenize string, factory
        self.compile(expressions)
      end

      protected def self.compile(expressions : Array(Expression(E))) : Expression(E)
        rpn_exp = self.rpn(expressions)
        self.build_ast(rpn_exp)
      end

      # 读取atomic的token
      protected def self.read_token(string : String, start : Int32 = 0) : String
        parens = Array(Char).new
        nextExpression = start
        while nextExpression < string.size
          c = string[nextExpression]
          matcher = nil
          LiteralPatterns.each do |pattern|
            matcher = pattern.match(string, nextExpression)
            # 必须从 0 开始匹配，如果不是，那么仍然是不匹配的
            matcher = nil if matcher && matcher.begin != nextExpression
            break unless matcher.nil?
          end
          match = matcher.try &.[0]
          if !match.nil?
            nextExpression += match.size - 1
          elsif c == '('
            parens << c
          elsif c == ')'
            break if parens.empty?
            parens.pop
          elsif c == '&' || c == '|'
            break
          end
          nextExpression += 1
        end
        token = string[start...nextExpression].strip
        raise Exception::TokenizeLogicException.new("zero-length token found.") if token.empty?
        token
      rescue e : ::Exception
        raise Exception::TokenizeLogicException.new("Error parsing token: " + string[start..-1], e)
      end

      # 将逻辑表达式 tokenize
      protected def self.tokenize(input : String, factory : String -> Expression::Pred(E)) : Array(Expression(E))
        tokens = Array(Expression(E)).new
        nonsense_expression = Apply::Nonsense(E).new
        i = 0
        while i < input.size
          firstchar = input[i]
          case firstchar
          when ' '
            i += 1
          when '('
            tokens << Paren::L(E).new
            i += 1
          when ')'
            tokens << Paren::R(E).new
            i += 1
          when '!'
            tokens << Apply::Op::Mon::Not(E).new(nonsense_expression)
            i += 1
          when '&'
            tokens << Apply::Op::Bin::And(E).new(nonsense_expression, nonsense_expression)
            i += 1
          when '|'
            tokens << Apply::Op::Bin::Or(E).new(nonsense_expression, nonsense_expression)
            i += 1
          else
            token = self.read_token input, i
            tokens << factory.call(token)
            i += token.size
          end
        end
        tokens
      end

      protected def self.build_ast(rpn : Array(Expression(E))) : Expression(E)
        raise Exception::CompileLogicException.new("empty rpn") if rpn.empty?
        stack = Array(Apply(E)).new
        rpn.each do |tok|
          if tok.is_a? Apply::Arg(E)
            stack << tok.as(Apply(E))
          elsif tok.is_a? Apply::Op(E)
            begin
              if tok.is_a? Apply::Op::Mon(E)
                sub = stack.pop
                mon = tok.as(Apply::Op::Mon(E))
                mon.sub = sub
                stack << mon
              end
              if tok.is_a? Apply::Op::Bin(E)
                arg2 = stack.pop
                arg1 = stack.pop
                bin = tok.as(Apply::Op::Bin(E))
                bin.left = arg1
                bin.right = arg2
                stack << bin
              end
            rescue e : Exception::EmptyStackException
              raise Exception::CompileLogicException.new("No argument for operator (stack empty): #{tok}")
            end
          end
        end
        if stack.size > 1
          raise Exception::ApplyLogicException.new("Stack has multiple elements after apply: #{stack}")
        end
        if stack.size == 0
          raise Exception::ApplyLogicException.new("Stack has zero elements after apply.")
        end
        unless stack[0].is_a? Apply(E)
          raise Exception::ApplyLogicException.new("Stack contains non-appliable tokens after apply: #{stack}")
        end
        stack[0]
      end

      # 将逻辑表达式token转成逆波兰表达式
      protected def self.rpn(tokens : Array(Expression(E))) : Array(Expression(E))
        stack = Array(Expression(E)).new
        output = Array(Expression(E)).new
        tokens.each do |tok|
          case tok
          when Paren::L(E)
            stack << tok
          when Paren::R(E)
            while true
              top = stack.pop
              if !top.is_a? Paren::L(E)
                output << top
                next
              else
                break
              end
            end
          when Apply::Op::Mon(E)
            stack << tok
          when Apply::Op::Bin(E)
            while !stack.empty? && stack[-1].is_a?(Apply::Op(E)) && stack[-1].as(Apply::Op(E)).preceeds(tok)
              output << stack.pop
            end
            stack.push tok
          when Apply::Arg(E)
            output << tok
          end
        end
        while !stack.empty?
          top = stack.pop
          if top.is_a?(Paren::L(E)) || top.is_a?(Paren::R(E))
            raise Exception::CompileLogicException.new("Unbalanced parentheses.")
          end
          output << top
        end
        output
      end
    end
  end
end
