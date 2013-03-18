require "rubygems"
require "bundler/setup"

require "pstore" # used over YAML for novelty.
require "google_drive"
require "pry"    # my fav console evar

# Our Google OAuth widget
require File.join(File.dirname(__FILE__), 'connect_to_drive.rb')

STORE = File.join(File.dirname(__FILE__), 'pathfinder.pstore')

module Pathfinder
    
    STORAGE = PStore.new(STORE)

    module Tools
        # This is where all the in-game functions are defined
        # TODO load in character variables
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

        def single_roll(sides, crit_level = 19)
            res = 1 + rand(sides)
            if sides == 20 and res >= crit_level
                puts "Crit: rolled #{res}"
            end
            res
        end

        def roll(dice = 1, sides = 6, crit_level = 19)
            """roll a number of dice with a number of sides"""
            (dice..dice).to_a.map{ |_| single_roll(sides, crit_level) }
        end

        def check(skill = 0)
            """Perform a standard (d20) check with the provided bonus"""
            sum(roll(1, 20)) + skill
        end

        # roll to hit
        def atk_roll(bonus = 0, base = 14)
            check(base) + bonus
        end

        # roll for damage
        def normal_damage(magic_damage_dice = 2)
            magic = sum(roll(magic_damage_dice, 6)) + 2
            dagger = sum(roll(1, 4)) + 2
            [magic, dagger]
        end

        def sneak_damage(magic_damage_dice = 2)
            """Rolls 5d6 + normal damage"""
            sneak = sum(roll(5, 6))
            reg = normal_damage(magic_damage_dice)
            reg << sneak
            reg
        end
    end

    # Used to download character sheet data from Google Drive
    class CharacterSheet
        # session: a google_drive session
        # key: the Drive identifier for the character sheet document
        #   (it's the key= query param when you load the char sheet in the browser)
        
        STATS_SHEET = 'Stats, Skills, Weapons'

        # for scraping the skills
        #SKILLS_CELL = 'AH16:AM16'
        SKILLS_CELL = 'AH16'
        SKILLS_ROWS = 38

        attr_reader :doc, :stats

        def initialize(session, key)
            @doc = session.spreadsheet_by_key(key)

            # all we need for now
            @stats = @doc.worksheet_by_title(STATS_SHEET)
            @sheets = [@stats]

            if @stats.nil?
                raise "Couldn't load the Stats charsheet"
            end
        end

        def refresh
            @sheets.each {|s| s.reload()}
        end

        def skills(start_loc = SKILLS_CELL, offset = 6)
            # scrape the spreadsheet skills list
            skills = {}
            start, names_col = @stats.cell_name_to_row_col(start_loc)
            skills_col = names_col + offset
            (start..start+SKILLS_ROWS).each do |row|
                # more clear to split this up
                skill_name = @stats[row, names_col]
                skill_val  = @stats[row, skills_col]
                skills[skill_name] = skill_val
            end

            skills
        end
    end

    class StateManager

        # for ease of use
        attr_accessor :token, :key, :session, :auth

        def initialize(storage = Pathfinder::STORAGE)
            @storage = storage
        end

        def set_doc_key(key)
            @key = key
            @storage.transaction do
                @storage[:doc] = @key
            end
        end

        def get_character_sheet
            if @key.nil?
                @storage.transaction do 
                    @key = @storage[:doc]
                end
            end

            if @key.nil?
                raise 'No key stored. See StateManager#set_doc_key'
            end

            @auth = Pathfinder::OAuth.new
            @token = auth.load_token

            if @token.nil?
                raise 'No OAuth credentials stored'
            end

            @session = GoogleDrive.login_with_oauth(@token)
            return Pathfinder::CharacterSheet.new(@session, @key)
        end
    end


end


include Pathfinder
# Boom, UI.
binding.pry
