# Copyright (c) 2016, 2017 Oracle and/or its affiliates. All rights reserved. This
# code is released under a tri EPL/GPL/LGPL license. You can use it,
# redistribute it and/or modify it under the terms of the:
#
# Eclipse Public License version 1.0, or
# GNU General Public License version 2, or
# GNU Lesser General Public License version 2.1.

Truffle::Boot.delay do
  wd = Truffle::Boot.get_option('working_directory')
  Dir.chdir(wd) unless wd.empty?
end

if Truffle::Boot.ruby_home
  # Always provided features: ruby --disable-gems -e 'puts $"'
  begin
    require 'enumerator'
    require 'thread'
    require 'rational'
    require 'complex'
    require 'unicode_normalize'
  rescue LoadError => e
    Truffle::Debug.log_warning "#{File.basename(__FILE__)}:#{__LINE__} #{e.message}"
  end

  if Truffle::Boot.get_option 'rubygems'
    Truffle::Boot.delay do
      if Truffle::Boot.resilient_gem_home?
        ENV.delete 'GEM_HOME'
        ENV.delete 'GEM_PATH'
        ENV.delete 'GEM_ROOT'
      end
    end

    begin
      Truffle::Boot.print_time_metric :'before-rubygems'
      begin
        if Truffle::Boot.get_option('rubygems.lazy')
          require 'truffle/lazy-rubygems'
        else
          Truffle::Boot.delay do
            require 'rubygems'
          end
        end
      ensure
        Truffle::Boot.print_time_metric :'after-rubygems'
      end
    rescue LoadError => e
      Truffle::Debug.log_warning "#{File.basename(__FILE__)}:#{__LINE__} #{e.message}"
    else
      if Truffle::Boot.get_option 'did_you_mean'
        Truffle::Boot.print_time_metric :'before-did-you-mean'
        begin
          $LOAD_PATH << "#{Truffle::Boot.ruby_home}/lib/ruby/gems/#{Truffle::RUBY_BASE_VERSION}/gems/did_you_mean-1.1.0/lib"
          require 'did_you_mean'
        rescue LoadError => e
          Truffle::Debug.log_warning "#{File.basename(__FILE__)}:#{__LINE__} #{e.message}"
        ensure
          Truffle::Boot.print_time_metric :'after-did-you-mean'
        end
      end
    end
  end
end

# Post-boot patching when using context pre-initialization
if Truffle::Boot.preinitializing?
  old_home = Truffle::Boot.ruby_home
  if old_home
    # We need to fix all paths which capture the image build-time home to point
    # to the runtime home.
    Truffle::Boot.delay do
      new_home = Truffle::Boot.ruby_home
      [$LOAD_PATH, $LOADED_FEATURES].each do |array|
        array.each do |path|
          if path.start_with?(old_home)
            path.replace(new_home + path[old_home.size..-1])
          end
        end
      end
    end
  end
end
