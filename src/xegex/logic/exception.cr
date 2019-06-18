module Xegex
  module Exception
    # 逻辑表达式的异常
    class LogicException < ::Exception
    end

    # 匹配entity的过程中的异常
    class ApplyLogicException < LogicException
    end

    # 构建逻辑表达式过程中的异常
    class CompileLogicException < LogicException
    end

    # 对于逻辑表达式进行分词的时候的异常
    class TokenizeLogicException < LogicException
    end

    class EmptyStackException < LogicException
    end
  end
end
