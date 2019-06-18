module Xegex
  module Exception
    class RegexException < ::Exception
    end

    class TokenizationRegexException < RegexException
    end

    class IllegalStateException < RegexException
    end

    class IllegalArgumentException < RegexException
    end
  end
end
