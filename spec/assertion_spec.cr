require "./spec_helper"

macro evaluate(regex, tokens, value)
  it "#{{{value}} ? "" : "not"} be found in '#{{{tokens}}.join(" ")}'" do
    {{regex}}.apply({{tokens}}).should eq({{value}})
  end
end

describe Xegex do
  # TODO: Write tests
  regex_tokens = ["^", "<is>", "<a>", "$"]
  match_tokens = ["this", "is", "a", "test"]
  regex = RE(String).compile regex_tokens[1...-1].join(" "), &RF::WordMatch
  regex_end = RE(String).compile regex_tokens[1..-1].join(" "), &RF::WordMatch
  regex_start = RE(String).compile regex_tokens[0...-1].join(" "), &RF::WordMatch
  regex_both = RE(String).compile regex_tokens.join(" "), &RF::WordMatch

  describe regex.to_s do
    evaluate(regex, match_tokens, true)
    evaluate(regex, match_tokens[1..-1], true)
    evaluate(regex, match_tokens[0...-1], true)
  end

  describe regex_end.to_s do
    evaluate(regex_end, match_tokens, false)
    evaluate(regex_end, match_tokens[1..-1], false)
    evaluate(regex_end, match_tokens[0...-1], true)
  end

  describe regex_start.to_s do
    evaluate(regex_start, match_tokens, false)
    evaluate(regex_start, match_tokens[1..-1], true)
    evaluate(regex_start, match_tokens[0...-1], false)
  end

  describe regex_both.to_s do
    it "match? 'is a'" do
      regex_both.match?(["is", "a"]).should eq(true)
    end
    evaluate(regex_both, match_tokens, false)
    evaluate(regex_both, match_tokens[1..-1], false)
    evaluate(regex_both, match_tokens[0...-1], false)
  end
end
