require "./spec_helper"

def compile_s(pat)
  LE(String).compile pat, &LF::StringMatch
end

def substitute(expr : String, varargs : Array(Bool))
  varargs.each_with_index do |bool, idx|
    v = 'a' + idx
    expr = expr.gsub(v, "'#{bool.to_s}'")
  end
  expr
end

def compile_t(pat)
  LE(WordToken).compile pat do |expr|
    part, quotedValue = expr.split "="
    value = quotedValue[1...-1]
    LE::Pred(WordToken).new expr do |entity|
      case part
      when "string"
        entity.string == value
      when "postag"
        entity.postag == value
      when "chunk"
        entity.chunk == value
      else
        false
      end
    end
  end
end

macro check(expr_s, &f)
  it "evaluate (#{{{expr_s}}}) correctly" do
    [true, false].repeated_permutations({{f.args.size}}).each do |args|
      expr = compile_s substitute({{expr_s}}, args)
    f2 = ->(){
      {% for i in 0...f.args.size %}
      {{f.args[i]}} = args[{{i}}]
      {% end %} {{f.body}}
    }
      expr.apply("true").should eq(f2.call)
    end
  end
end

describe Xegex do
  describe "logic" do
    it "escape characters" do
      exp = compile_s "\"zebra\" | \"zeb\\\"ra\""
      exp.apply("zeb\\\"ra").should eq(true)
    end
    it "order of operations" do
      compile_s("false & false & false").to_s.should eq("(false & (false & false))")
      compile_s("false & false | false").to_s.should eq("((false & false) | false)")
      compile_s("false | false & false").to_s.should eq("(false | (false & false))")
    end

    describe "two variable logic expressions" do
      check("a | b") { |a, b| a | b }
      check("a & b") { |a, b| a & b }
    end
    describe "three variable logic expressions" do
      check("(a | (b & c))") { |a, b, c| a | (b & c) }
      check("(a & (b & c))") { |a, b, c| a & (b & c) }
      check("(a & (b | c))") { |a, b, c| a & (b | c) }
      check("(a | (b | c))") { |a, b, c| a | (b | c) }
    end

    describe "four variable logic expressions" do
      check("(a | (b & c & d))") { |a, b, c, d| a | (b & c & d) }
      check("(a | (b & c | d))") { |a, b, c, d| a | (b & c | d) }
      check("(a | (b | c & d))") { |a, b, c, d| a | (b | c & d) }
      check("(a | (b | c | d))") { |a, b, c, d| a | (b | c | d) }
      check("(a & (b & c & d))") { |a, b, c, d| a & (b & c & d) }
      check("(a & (b & c | d))") { |a, b, c, d| a & (b & c | d) }
      check("(a & (b | c & d))") { |a, b, c, d| a & (b | c & d) }
      check("(a & (b | c | d))") { |a, b, c, d| a & (b | c | d) }
      check("((a | b) & (c | d))") { |a, b, c, d| (a | b) & (c | d) }
      check("((a & b) | (c & d))") { |a, b, c, d| (a & b) | (c & d) }
      check("(!(a | b) & (c | d))") { |a, b, c, d| !(a | b) & (c | d) }
      check("((a | b) & !(c | d))") { |a, b, c, d| (a | b) & !(c | d) }
      check("(!((a | b) & !(c | d)))") { |a, b, c, d| !((a | b) & !(c | d)) }
    end
    describe "word token" do
      logic = compile_t("string='the' | postag='JJ'")
      logic.apply(WordToken.new("the", "foo", "bar")).should eq(true)
      logic.apply(WordToken.new("foo", "JJ", "bar")).should eq(true)
      logic.apply(WordToken.new("foo", "bar", "baz")).should eq(false)
    end
  end
end
