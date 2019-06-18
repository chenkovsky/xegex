require "./spec_helper"

class TestCase
  @tokens : Array(String)
  @value : Bool

  getter :tokens, :value

  def initialize(@tokens, @value)
  end

  def extends(test : TestCase)
    TestCase.new(tokens + test.tokens, value & test.value)
  end

  def <=>(that : TestCase)
    c1 = tokens.join(" ") <=> that.tokens.join(" ")
    if c1 != 0
      return c1
    end
    return value <=> that.value
  end
end

def cases(regex)
  make_cases(regex.expressions)
end

def make_cases(exprs)
  Set.new rec(exprs)
end

def make_next(expr : RE(String)) : {Array(Array(String)), Array(Array(String))}
  case expr
  when RE::Star(String)
    source = expr.expr.as(RE::Base::Lambda(String)).source
    {[] of Array(String), [[] of String, [source], [source, source]]}
  when RE::Plus(String)
    source = expr.expr.as(RE::Base::Lambda(String)).source
    {[[] of String] of Array(String), [[source], [source, source]]}
  when RE::Option(String)
    source = expr.expr.as(RE::Base::Lambda(String)).source
    {[[source, source]], [[] of String, [source]]}
  when RE::Base::Lambda(String)
    source = expr.source
    {[[] of String, [source, source]], [[source]]}
  else
    {[] of Array(String), [] of Array(String)}
  end
end

def make_next_case(expr : RE(String))
  falses, trues = make_next(expr)
  falses.map { |x| TestCase.new(x, false) } + trues.map { |x| TestCase.new(x, true) }
end

def combine(tests : Array(TestCase), nexts : Array(TestCase))
  if nexts.empty?
    return tests
  end
  tests.zip(nexts).map { |t, n| t.extends n }
end

def rec(exprs) : Array(TestCase)
  if exprs.empty?
    return [] of TestCase
  end
  tests = make_next_case(exprs[0])
  extensions = rec(exprs[1..-1])
  combine tests, extensions
end

describe Xegex do
  tokens = ["<this>+", "<is>*", "<a>?", "<test>"]
  tokens.permutations.each do |p|
    it "match sentences correctly" do
      regex = RE(String).compile p.join(" "), &RF::WordMatch
      cases(regex).each do |t|
        regex.match?(t.tokens).should eq(t.value)
      end
    end
  end
end
