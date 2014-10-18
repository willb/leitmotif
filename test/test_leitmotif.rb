require 'helper'

class TestLeitmotif < MiniTest::Test
    ### A simple test.
    context "Leitmotif core tests" do
            setup do
                @lm = Leitmotif.new
            end

            should "run should return 1 if arguments are invalid"
                x=@lm.run("","")
                assert_equal 1, x
            end

    end
end

