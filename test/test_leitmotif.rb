require 'helper'
require 'rspec'


describe Leitmotif do
    it "should return 1 if arguments are invalid" do
        @lm = Leitmotif.new
        x = @lm.run("","")
        assert_equal 1, x
    end
end
