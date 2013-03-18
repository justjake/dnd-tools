require "rubygems"
require "bundler/setup"

require "oauth2"
require "pstore" # used over YAML for novelty.

STORE = File.join(File.dirname(__FILE__), 'oauth.pstore')

#CLIENT_ID = ENV['CLIENT_ID']
#CLIENT_SECRET = ENV['CLIENT_SECRET']

# TODO: move into ENV
CLIENT_ID =     '539096868219.apps.googleusercontent.com'
CLIENT_SECRET = 'HSJKoPRwscFvYvkP-6HhmEaH'

# this tells Google what permissions we are requesting
#SCOPE = 'https://www.googleapis.com/auth/drive.file'
SCOPE = 'https://www.googleapis.com/auth/drive.readonly'
# SCOPE = 'https://www.googleapis.com/auth/drive'

REDIRECT_URI = 'https://localhost.com/OAUTH'

module Pathfinder
    class OAuth
        # Pass in a PSTORE or one will be created for you
        def initialize(storage = nil)
            @client = OAuth2::Client.new(CLIENT_ID, CLIENT_SECRET, {
                :site => 'https://accounts.google.com',
                :authorize_url => '/o/oauth2/auth',
                :token_url => '/o/oauth2/token'
            })

            @storage = storage || PStore.new(STORE)
        end

        def authorize()
            # Step 1
            puts "Paste this URL into your browser to connect this app with Google: "
            puts @client.auth_code.authorize_url(
                :scope => SCOPE, 
                :access_type => 'offline', 
                :redirect_uri => REDIRECT_URI,
                :approval_prompt => 'force'
            )

            # Step 2 is performed in the browser by the user

            # Step 3
            puts "Paste the `code` parameter from the redirect URL here to finish authorization: "
            code = gets.chomp.string

            @access_token = @client.auth_code.get_token(code, {
                :redirect_uri => REDIRECT_URI,
                :token_method => :post
            })
        end

        def save_token()
            if @access_token.nil?
                raise 'No access token to store'
            end

            # wow look at the saftey!
            @storage.transation do
                @storage[:token] = @access_token.token
                @storage[:refresh_token] = @access_token.refresh_token
            end

        end

        def load_token()
            token = nil
            refresh = nil

            @storage.transaction do
                token = @storage[:token]
                refresh = @storage[:refresh_token]
            end

            if token.nil? or refresh.nil?
                raise 'Could not load token from storage'
            end

            @access_token = OAuth2::AccessToken.new(@client, token, :refresh_token => refresh)
            @access_token.refresh!
            @access_token
        end
    end
end
