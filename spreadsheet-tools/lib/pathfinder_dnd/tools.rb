module Pathfinder

    # This is where all the in-game functions are defined, like rolling dice.
    # Also includes some analytics, like an `average` function.
    module Tools

        # Deep sum arrays of integers and arrays.
        # @param array [Array] the list to sum up.
        # @return [Integer] the total
        def sum(array)
            res = 0

            # numbers sum to themselves
            return array if array.is_a? Fixnum

            array.each do |i|
                if i.respond_to? :each
                    res += sum(i)
                else
                    res += i
                end
            end
            res
        end

        # Roll one dice with N sides.
        # When rolling 20-sided dice, alerts on very high or low rolls.
        #
        # @param sides [Integer] number of sides on the dice.
        # @param crit_level [Integer] alert the user to dice 
        #   rolls at or above this level when rolling 20-sided dice. Default 19.
        # @param failure_level [integer] alert the user to dice rolls
        #   at or below this level when rolling 20-sided dice. Default 1.
        # @return [Integer] result of the dice roll
        def single_roll(sides, crit_level = 0, failure_level = 1)
            res = 1 + rand(sides)
            if res >= crit_level + sides and @verbose
                puts "High roll: rolled #{res} on a d#{sides}"
            end

            if res <= failure_level and @verbose
                puts "Low roll:  rolled #{res} on a d#{sides}"
            end

            res
        end


        # Roll a number of dice
        # @param dice [Integer] number of dice to roll. Default 1.
        # @param sides [Integer] number of sides on each die. Default 6.
        # @see #single_roll
        # @return [Array<Integer>] list of dice roll results
        def roll(dice = 1, sides = 6, crit_level = 0, failure_level = 1)
            (1..dice).to_a.map{ |_| single_roll(sides, crit_level, failure_level) }
        end

        # Roll a 20-sided dice and add an optional skill bonus
        # Alerts the user on 19-20 rolls
        # @param skill [Integer] your skill-check or saving-throw bonus. Default 0.
        # @return [Integer]
        def check(skill = 0)
            verbose do 
                single_roll(20, -1) + skill
            end
        end

        # Average the many runs of a function.
        # Intended to benchmark your damage.
        #
        # @param runs [Integer] how many samples to take
        # @param fn_name [String, Symbol] name of the method to call
        # @param block [Proc] a block to use instead of calling a defined method
        # @return [Integer] the average
        def average(runs = 100, fn_name = nil, &block)
            res = 0

            if fn_name
                b = method(fn_name.to_sym)
            else
                b = block
            end

            runs.times { res += sum(b.call()) }
            res / runs
        end

        # roll verbosely
        def verbose(&block)
            old_v = @verbose
            @verbose = true
            res = block.call()
            @verbose = old_v

            res
        end
    end
end
