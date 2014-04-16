require 'optparse'
require 'httparty'
require_relative 'settings'

class KerioMonitor
  include HTTParty

  def initialize
    check_if_root
    setup_httparty
    handle_arguments!
    login
  end

  def check_if_root
    if ENV['USER'] != 'root'
      puts 'You need root privileges to run this script'
      exit 1
    end
  end

  def setup_httparty
    self.class.base_uri '127.0.0.1'
    self.class.format :json
    self.class.headers(
        {
            Accept: 'application/json-rpc',
            ContentType: 'application/json-rpc',
            Host: '127.0.0.1:4040',
            Connection: 'close'
        }
    )
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
        }
    }
    response = self.class.post '/admin/api/jsonrpc/', options
    puts response.code
  end

end