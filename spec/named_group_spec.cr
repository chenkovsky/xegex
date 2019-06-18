require "./spec_helper"

describe Xegex do
  regex = RE(String).compile "(<subject>: <I> | (?: <The> (<subjadj>: <crazy>)? <Mariners>)) <know> <all> <of> (<poss>: <her> | (?: <the> (<possadj>: <dirty>?) <King> <'s>)) <secrets>", &Factory::WordMatch
  matches = ["I know all of her secrets",
             "The Mariners know all of her secrets",
             "The Mariners know all of the dirty King 's secrets",
             "The Mariners know all of the King 's secrets",
             "The crazy Mariners know all of the King 's secrets"]
  matches.each do |m|
    # it "match against " + m do
    #   regex.apply(m.split(" ")).should eq(true)
    # end
  end
  it "yield the correct groups" do
    m_ = regex.find("The crazy Mariners know all of the King 's secrets".split(" "))
    m_.nil?.should eq(false)
    m = m_.not_nil!
    m.groups.size.should eq(5)
    m["subject"].text.should eq("The crazy Mariners")
    m["subject"].start_index.should eq(0)
    m["subject"].end_index.should eq(2)

    m["subjadj"].text.should eq("crazy")
    m["subjadj"].start_index.should eq(1)
    m["subjadj"].end_index.should eq(1)

    m["poss"].text.should eq("the King 's")
    m["poss"].start_index.should eq(6)
    m["poss"].end_index.should eq(8)

    m["possadj"].text.should eq("")
    m["possadj"].start_index.should eq(-1)
    m["possadj"].end_index.should eq(-1)
  end
  it "yield the correct groups" do
    m_ = regex.find("The Mariners know all of her secrets".split(" "))
    m_.nil?.should eq(false)
    m = m_.not_nil!
    m.groups.size.should eq(3)

    m["subject"].text.should eq("The Mariners")
    m["subject"].start_index.should eq(0)
    m["subject"].end_index.should eq(1)

    m["poss"].text.should eq("her")
    m["poss"].start_index.should eq(5)
    m["poss"].end_index.should eq(5)
  end
end
