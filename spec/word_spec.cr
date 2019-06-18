require "./spec_helper"

def compile(string : String) : RE(WordToken)
  RE(WordToken).compile(string) do |str|
    part, quoted_value = str.split("=")
    value = quoted_value[1...-1]
    RE::Base::Lambda(WordToken).new str do |entity|
      case part
      when "string"
        entity.string.downcase == value
      when "postag"
        entity.postag == value
      when "chunk"
        entity.chunk == value
      else
        raise "Cannot be here"
      end
    end
  end
end

describe Xegex do
  it "work" do
    sentence = "The US president Barack Obama is travelling to Mexico."
    tokens = [
      WordToken.new("The", "DT", nil),
      WordToken.new("US", "NNP", nil),
      WordToken.new("president", "NN", nil),
      WordToken.new("Barack", "NNP", nil),
      WordToken.new("Obama", "NNP", nil),
      WordToken.new("is", "VB", nil),
      WordToken.new("travelling", "VB", nil),
      WordToken.new("to", "TO", nil),
      WordToken.new("Mexico", "NN", nil),
      WordToken.new(".", ".", nil),
    ]
    regex = compile("(?:<string='a'> | <string='an'> | <string='the'>)? <postag='JJ'>* <postag='NNP'>+ <postag='NN'>+ <postag='NNP'>+")
    found_ = regex.find(tokens)
    found_.nil?.should eq(false)
    found = found_.not_nil!
    found.groups.size.should eq(1)
    found[0].tokens.map { |x| x.entity.string }.join(" ").should eq("The US president Barack Obama")
  end
end
