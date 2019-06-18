require "spec"
require "../src/xegex"

class WordToken
  @string : String
  @postag : String
  @chunk : String?
  getter :string, :postag, :chunk

  def initialize(@string, @postag, @chunk)
  end

  def to_s(io)
    io << "#{@string}/#{@postag}/#{@chunk}"
  end
end

include Xegex::Logic
include Xegex::Regex
alias RE = Xegex::Regex::Expression
alias RF = Xegex::Regex::Factory
alias LE = Xegex::Logic::Expression
alias LF = Xegex::Logic::Factory
