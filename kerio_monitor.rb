require 'optparse'
require 'httparty'
require_relative 'settings'

class KerioMonitor
  include HTTParty

  def initialize
    check_if_root
    get_settings
    setup_httparty
    handle_arguments!
    login
    logout
  end

  def get_settings
    Dir.chdir File.dirname(__FILE__)
    if File.exist? File.dirname(__FILE__)+'/config.yml'
      Settings.load!
    else
      Settings.create!
    end
  end

  def check_if_root
    if ENV['USER'] != 'root'
      puts 'You need root privileges to run this script'
      exit 1
    end
  end

  def setup_httparty
    self.class.base_uri 'https://elisa.avalonia.dk:4040'
    self.class.format :json
    @headers = {
        'Accept' => 'application/json-rpc',
        'Content-Type' => 'application/json-rpc',
        'Connection' => 'close'
    }
    self.class.headers @headers
  end

  def handle_arguments!
    o = OptionParser.new do |opts|
      opts.banner = 'Usage: kerio_monitor.rb [options]'
      opts.on_tail('-h', '--help', 'Show this message.') do
        puts opts
        exit
      end

    end
    begin o.parse!
    rescue OptionParser::InvalidOption => e
      puts e
      puts o
      exit 1
    end
  end

  def login
    options = {
        body: {
            jsonrpc: '2.0',
            id: 1,
            method: 'Session.login',
            params: {
                userName: Settings.kerio_user,
                password: Settings.kerio_pass,
                application: {
                    name: 'Kerio Monitor',
                    vendor: 'Avalonia.net',
                    version: '1.0.0'
                }
            }
        }.to_json
    }
    response = self.class.post '/admin/api/jsonrpc/', options
    if response.code != 200
      puts 'Error logging in'
      exit 1
    end
    puts 'Logged in!'
    headers = response.headers
    puts headers.inspect
    puts response.body
    puts headers['Set-Cookie']
    @headers['Cookie'] = headers['Set-Cookie']
    parsedbody = JSON.parse(response.body)
    @headers['X-Token'] = parsedbody['result']['token']
  end

  def logout
    options = {
        headers: @headers,
        body: {
            jsonrpc: '2.0',
            id: 1,
            method: 'Session.logout'
        }.to_json
    }
    response = self.class.post '/admin/api/jsonrpc/', options
    puts response.body
    if response.code != 200
      puts 'Error logging in'
      exit 1
    end
    puts 'Logged out!'
  end

end

KerioMonitor.new