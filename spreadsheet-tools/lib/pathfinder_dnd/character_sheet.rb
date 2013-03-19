# D&D functions
require "pathfinder_dnd/tools"

module Pathfinder
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

        cell_reader :name,         'M2'
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
end
