$:.unshift(File.dirname(__FILE__) + '/../lib')
require File.dirname(__FILE__) + '/../init'
require 'spec'

describe Eve::Combatlog::Parser do
  
  it "sould run smothly" do
    Eve::Combatlog::Parser.new('./logs/file1.txt').should_not == nil
  end
  
end