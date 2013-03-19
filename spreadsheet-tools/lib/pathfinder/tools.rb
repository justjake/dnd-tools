#!/usr/bin/env ruby

module Pathfinder

    # This is where all the in-game functions are defined, like rolling dice.
    module Tools

        # Deep sum arrays of integers and arrays.
        # @param array [Array] the list to sum up.
        # @return [Integer] the total
        def sum(array)
            res = 0
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
        def single_roll(sides, crit_level = 19, failure_level = 1)
            res = 1 + rand(sides)
            if sides == 20 and res >= crit_level
                puts "Crit: rolled #{res}"
            end

            if sides == 20 and res <= failure_level
                puts "Low roll: rolled #{res}"
            end

            res
        end


        # Roll a number of dice
        # @param dice [Integer] number of dice to roll. Default 1.
        # @param sides [Integer] number of sides on each die. Default 6.
        # @see #single_roll
        # @return [Array<Integer>] list of dice roll results
        def roll(dice = 1, sides = 6, crit_level = 19, failure_level = 1)
            (1..dice).to_a.map{ |_| single_roll(sides, crit_level, failure_level) }
        end

        # Roll a 20-sided dice and add an optional skill bonus
        # @param skill [Integer] your skill-check or saving-throw bonus. Default 0.
        # @return [Integer]
        def check(skill = 0)
            sum(roll(1, 20)) + skill
        end

        # roll to hit
        # Rolls a basic check with an additional bonus
        # @param bonus [Integer] added bonus, usually from Anne's blung-ing or haste
        # @param base [Integer] your usual attack bonus. Character-specific default 14.
        # @see #check
        def atk_roll(bonus = 0, base = 14)
            check(base) + bonus
        end

        # roll for damage
        # Character-specific to Shalizara
        # @return [Array<Integer>] magic and normal components of the attack
        def normal_damage(magic_damage_dice = 2)
            magic = sum(roll(magic_damage_dice, 6)) + 2
            dagger = sum(roll(1, 4)) + 2
            [magic, dagger]
        end

        # Roll for sneak-attack damage
        # Character-specific to Shalizara
        # @see #normal_damage
        def sneak_damage(magic_damage_dice = 2)
            sneak = sum(roll(5, 6))
            reg = normal_damage(magic_damage_dice)
            reg << sneak
            reg
        end
    end
end
