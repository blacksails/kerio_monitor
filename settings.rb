require 'psych'
require 'io/console'

module Settings

  extend self

  @settings = {}

  def create!
    puts 'It appears that we lack a configuration file, lets create one now!'
    printf 'Enter kerio host address: '
    kerio_host = gets.chomp
    printf 'Enter kerio port: '
    kerio_port = gets.chomp
    printf 'Enter kerio admin username: '
    kerio_user = gets.chomp
    printf 'Enter kerio admin password: '
    kerio_pass = STDIN.noecho(&:gets).chomp; puts
    settings = {
        kerio_user: kerio_user,
        kerio_pass: kerio_pass
    }
    f = File.new(File.dirname(__FILE__)+'/config.yml', 'w')
    f.chown(-1,0)
    f.chmod(0600)
    f.write Psych.dump(settings)
    f.close
    load!
  end

  def load!
    @settings = Psych.load_file(File.dirname(__FILE__)+'/config.yml')
  end

  def method_missing(name, *args, &block)
    if @settings.has_key? name.to_sym
      @settings[name.to_sym]
    else
      @settings[name.to_sym] ||
          fail(NoMethodError, "unknown configuration root #{name}", caller)
    end
  end

end