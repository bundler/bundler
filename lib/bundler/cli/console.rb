module Bundler
  class CLI::Console
    attr_reader :options, :group
    def initialize(options, group)
      @options = options
      @group = group
    end

    def run
      group ? Bundler.require(:default, *(group.split.map! {|g| g.to_sym })) : Bundler.require
      ARGV.clear

      console = get_console(Bundler.settings[:console] || 'irb')
      load '.consolerc' if File.exists?('.consolerc')

      options[:load_paths].each do |dir|
        $LOAD_PATH.unshift(File.expand_path(dir))
      end

      console.start
    end

    def get_console(name)
      require name
      get_constant(name)
    rescue LoadError
      Bundler.ui.error "Couldn't load console #{name}"
      get_constant('irb')
    end

    CONSOLES = {
      'pry'  => :Pry,
      'ripl' => :Ripl,
      'irb'  => :IRB,
    }

    def get_constant(name)
      const_name = CONSOLES[name]
      Object.const_get(const_name)
    rescue NameError
      Bundler.ui.error "Could not find constant #{const_name}"
      exit 1
    end

  end
end
