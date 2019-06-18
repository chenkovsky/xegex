require "./spec_helper"

describe Xegex do
  regex = RE.compile("<this> <is> (((?:(?: <a> <very>+) | <an>) <amazing>? <new>{1,3}) | (?: <a> <many>* <centuries> <old>)) <test>", &RF::WordMatch)
  it "match" do
    regex.apply("this is a very very very amazing new test".split(" ")).should eq(true)
    regex.apply("this is a very new test".split(" ")).should eq(true)
    regex.apply("this is an amazing new test".split(" ")).should eq(true)
    regex.apply("this is a centuries old test".split(" ")).should eq(true)
    regex.apply("this is a many many centuries old test".split(" ")).should eq(true)
    regex.apply("this is a very new test".split(" ")).should eq(true)
    regex.apply("this is a very new new test".split(" ")).should eq(true)
    regex.apply("this is a very new new new test".split(" ")).should eq(true)
    regex.apply("this is a very new new new new test".split(" ")).should eq(false)
  end
  it "not match" do
    regex.apply("this is a amazing new test".split(" ")).should eq(false)
  end
  it "yield the correct groups" do
    m_ = regex.find("this is a very very very amazing new test".split(" "))
    m_.nil?.should eq(false)
    m = m_.not_nil!
    m.groups.size.should eq(3)
    m[1].text.should eq("a very very very amazing new")
    m[2].text.should eq("a very very very amazing new")
  end

  it "yield the correct groups" do
    m_ = regex.find("this is a centuries old test".split(" "))
    m_.nil?.should eq(false)
    m = m_.not_nil!
    m.groups.size.should eq(2)
    m[1].text.should eq("a centuries old")
  end
end
