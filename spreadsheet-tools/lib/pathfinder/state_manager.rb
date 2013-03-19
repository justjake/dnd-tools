#!/usr/bin/env ruby

require "pstore"

require "google_drive"

require "pathfinder/oauth"
require "pathfinder/character_sheet"

module Pathfinder

    # Default storage place
    STORAGE = PStore.new(File.expand_path('~/.config/pathfinder.pstore'))

    # Sets up the OAuth connection to Google Drive and manages user settings
    # such as the Google Drive key/id of the character sheet document.
    class StateManager

        # for ease of use
        attr_accessor :token, :session, :auth
        attr_reader   :doc_id

        # create a StateManager with a optional storage backend.
        # Loads data including OAuth tokens and the document identifier from the PStore
        # By default all StateMangers read/write to the Pathfinder settings
        # PStore in ~/.config/pathfinder.pstore
        def initialize(storage = Pathfinder::STORAGE)
            @storage = storage
            @auth = Pathfinder::OAuth.new(@storage)
            @token = @auth.load_token

            @storage.transaction do
                @doc_id = @storage[:doc]
            end
        end

        # Round-trip the user through Google's OAuth process
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

        # Perform all necessary input to get a character sheet from a user's Google Drive.
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
