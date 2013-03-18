#!/usr/bin/env ruby

# Run skill checks against the stats from your Google Drive character
# sheet.

require "rubygems"
require "bundler/setup"

require "pstore" # used over YAML for novelty.
require "google_drive"
require "pry"    # my fav console evar

# Our Google OAuth widget
require File.join(File.dirname(__FILE__), 'connect_to_drive.rb')

class Fixnum
    # In-line modifier scores
    def modifier
        ((self - 10) / 2).to_i
    end
end

module Pathfinder

    STORAGE = PStore.new(File.join(File.dirname(__FILE__), 'pathfinder.pstore'))

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


    # The whole of the Pathfinder Spreadsheet-tools environment.
    # The character-sheet provides one-word lookup of almost all essential 
    # character statistics.
    #
    # On a technical level, a CharacterSheet wraps access to a 
    # GoogleDrive::Worksheet with friendly helper methods. Skill accessor
    # methods are dynamically added at object instantiation.
    #
    # CharacterSheet is currently the gameplay interface, so it includes
    # Pathfinder::Tools for easy dice rolling, skill checks, and ninja 
    # business.
    class CharacterSheet

        # include standard D&D tools
        include Pathfinder::Tools
        
        # What sheet title to pull stats from?
        STATS_SHEET = 'Stats, Skills, Weapons'

        attr_reader :doc, :stats
        attr_accessor :hp

        # reads a cell directly from the spreadsheet.
        def self.cell_reader(name, row_or_coord, col = nil, sheet_index = 0)
            define_method(name) do 
                sheets = instance_variable_get('@sheets')
                sheet = sheets[sheet_index]

                if row_or_coord.is_a? Numeric
                    return sheet[row_or_coord, col].to_i
                else
                    return sheet[row_or_coord].to_i
                end
            end
        end

        ###############################
        # @!group Stats and Abilities
        # access modifiers like `strength.modifier`

        cell_reader :level,        'V5'

        # Ability stats
        cell_reader :strength,     'E14'
        cell_reader :dexterity,    'E17'
        cell_reader :constitution, 'E20'
        cell_reader :intelligence, 'E23'
        cell_reader :wisdom,       'E26'
        cell_reader :charisma,     'E29'

        # Defence
        cell_reader :max_hp,       'U11'
        cell_reader :ac,           'E33'
        cell_reader :touch_ac,     'E36'

        # Saving throws
        cell_reader :fortitude,    'H40'
        cell_reader :reflex,       'H42'
        cell_reader :will,         'H44'

        # Combat stuff
        cell_reader :initiative,   'W30'
        cell_reader :bab,          'L46'
        cell_reader :cmb,          'E50'
        cell_reader :cmd,          'E52'

        # @!endgroup
        ################################
        

        # session: a google_drive session
        # key: the Drive identifier for the character sheet document
        #   (it's the key= query param when you load the char sheet in the browser)
        def initialize(session, key)

            # This is where failure will occur if Oauth is fucked
            @doc = session.spreadsheet_by_key(key)


            # all we need for now
            @stats = @doc.worksheet_by_title(STATS_SHEET)
            @sheets = [@stats]

            if @stats.nil?
                raise "Couldn't load the Stats charsheet"
            end

            # set starting HP
            @hp = self.max_hp

            # write in skill values
            inject_instance_properties(get_raw_skills())
        end

        # Refeshes this instance with new data from the online character sheet, 
        # including updates to skills.
        def refresh
            @sheets.each {|s| s.reload()}
            inject_instance_properties(get_raw_skills())
        end

        # Builds a <String> => <Integer> hash of skill scores from the character spreadsheet.
        def get_raw_skills(start_loc = 'AH16', offset = 6)
            # scrape the spreadsheet skills list
            skills = {}
            start, names_col = @stats.cell_name_to_row_col(start_loc)
            skills_col = names_col + offset
            (start..start+38).each do |row|
                # more clear to split this up
                skill_name = @stats[row, names_col]
                skill_val  = @stats[row, skills_col]
                skills[skill_name] = skill_val.to_i
            end

            skills
        end

        # Injects a <String> => <Any> hash of properties into this instance as attribute accessors.
        # If the accessor methods already exist, then the local variables they wrap are updated.
        #
        # This method is used in conjuction with `get_raw_skill` to populate the intance with skill
        # fields at runtime.
        def inject_instance_properties(props)
            # for adding these properties to only THIS instance
            metaclass = (class << self; self; end)

            props.each do |name, value|
                safe_name = name.downcase.gsub(/\s/, '_').gsub(/[^a-zA-Z0-9_]/, '').to_sym

                # define the accessor for this skill if we haven't already
                if not self.respond_to? safe_name
                    metaclass.class_eval { attr_reader safe_name }
                end

                # update the skill value
                instance_variable_set("@#{safe_name}", value)
            end
        end
    end

    class StateManager

        # for ease of use
        attr_accessor :token, :session, :auth
        attr_reader   :doc_id

        def initialize(storage = Pathfinder::STORAGE)
            @storage = storage
            @auth = Pathfinder::OAuth.new(@storage)
            @token = @auth.load_token

            @storage.transaction do
                @doc_id = @storage[:doc]
            end
        end

        def authorize
            @auth.authorize
            @auth.save_token
            @token = @auth.access_token
        end

        def doc_id=(k)
            @doc_id = k
            @storage.transaction do
                @storage[:doc] = @doc_id
            end
        end

        def get_character_sheet
            if @token.nil?
                self.authorize()
            end

            if @doc_id.nil?
                puts "\n\nPaste the `key=` parameter from your character's Google Drive URL here:"
                self.doc_id = gets.chomp
            end


            @session = GoogleDrive.login_with_oauth(@token)

            return Pathfinder::CharacterSheet.new(@session, @doc_id)
        end
    end


end


# OAuth flow
state = Pathfinder::StateManager.new

# Set up the env...
character = nil
while character.nil?
    begin
        character = state.get_character_sheet
    rescue GoogleDrive::AuthenticationError => error
        puts "There was an error authenticating with Google Drive:\n"
        puts error.to_s
        puts "\n\nRe-linking with Google Drive..."
        state.authorize
    end
end

# Boom, UI.
Pry.config.prompt = [ proc { 'd&d>> ' }, proc { '  |  ' } ]


# all skills & most stats included
puts '--- Pathfinder Character Tools 2: Revenge of Google Docs ---
 version 0.2 "Beware of OAuth"

    You are in a fully-interactive ruby console. 
    You can `ls` to see methods.

    Roll basic skill checks and saving throws by typing `check <bonus>`
    You can roll a 20-sided dice using `check` without a bonus.
    Roll dice with `roll <count>, <sides>`
    Tab completion is enabled.

    type `help` for an overview of console usage
    type `show-doc <method>` to view help for that specific method

'
    
character.pry
