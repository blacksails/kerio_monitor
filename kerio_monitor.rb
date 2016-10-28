#!/usr/bin/env ruby
require 'optparse'
require 'httparty'
require 'json'
require_relative 'settings'

class KerioMonitor
  include HTTParty

  def initialize
    check_if_root
    get_settings
    setup_httparty
    handle_arguments!
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
    if Process.uid != 0
      puts 'You need root privileges to run this script'
      exit 1
    end
  end

  def setup_httparty
    self.class.base_uri 'https://'+Settings.kerio_host+':'+Settings.kerio_port
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
      opts.on('-q', '--queue-length',
              'Returns number of queued messages, and exit code 1 if the number is above 100.') { handle_q_flag }
      opts.on('-o', '--reference-count',
              'Returns largest opened folder reference count') { handle_o_flag }
      opts.on('-r', '--reset-config', 'Resets the config file') do
        if File.exist? File.dirname(__FILE__)+'/config.yml'
          File.delete File.dirname(__FILE__)+'/config.yml'
        end
      end
    end
    begin o.parse!
    rescue OptionParser::InvalidOption => e
      puts e
      puts o
      exit 1
    end
  end

  def handle_q_flag
    login
    options = {
        body: {
            jsonrpc: '2.0',
            id: 1,
            method: 'Queue.get',
            params: {
                query: {
                    fields: ['id'],
                    start: 0,
                    limit: 10000
                }
            }
        }.to_json
    }
    response = self.class.post '/admin/api/jsonrpc/', options
    logout
    if response.code != 200
      puts 'Error getting queued messages'
      exit 1
    end
    parsedresponse = JSON.parse response.body
    puts parsedresponse['result']['list'].length
    if parsedresponse['result']['list'].length < 100
      exit
    else
      exit 1
    end
  end

  def handle_o_flag
    login
    options = {
        body: {
            jsonrpc: '2.0',
            id: 1,
            method: 'Server.getOpenedFoldersInfo',
            params: {
              query: {
                fields: ["referenceCount"],
                start: 0,
                limit: 1,
                orderBy: [
                  {
                    columnName: "referenceCount",
                    direction: "Desc"
                  }
                ]
              }
            }
        }.to_json
    }
    response = self.class.post '/admin/api/jsonrpc/', options
    logout
    if response.code != 200
      puts 'Error getting max folder references'
      exit 255
    end
    parsedresponse = JSON.parse response.body
    max_ref_count = parsedresponse['result']['list'].first['referenceCount']
    puts max_ref_count
    if max_ref_count >= 255
      exit 255
    end
    exit max_ref_count
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
    headers = response.headers
    @headers['Cookie'] = headers['Set-Cookie']
    parsedbody = JSON.parse(response.body)
    @headers['X-Token'] = parsedbody['result']['token']
    self.class.headers @headers
  end

  def get_queue

  end

  def logout
    options = {
        body: {
            jsonrpc: '2.0',
            id: 1,
            method: 'Session.logout'
        }.to_json
    }
    response = self.class.post '/admin/api/jsonrpc/', options
    if response.code != 200
      puts 'Error logging out'
      exit 1
    end
  end

end

KerioMonitor.new
