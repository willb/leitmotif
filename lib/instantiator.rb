# Copyright (c) 2014 William C. Benton and Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

USE_ERUBIS = false

# XXX: refactor this ugliness
if USE_ERUBIS

  require 'erubis'

  class Instantiator
    DEFAULT_OPTIONS = {:safe_level => 3}

    def initialize(hash, options = nil)
      @vars = hash.dup
      @options = DEFAULT_OPTIONS.merge((options || {}))
    end

    def process(input)
      Erubis::Eruby.new(template).result(@vars)
    end
  end

else # USE_ERUBIS

  require 'erb'

  class Instantiator
    DEFAULT_OPTIONS = {:safe_level => 3}
    
    # this is the least terrible way to instantiate ERb with a hash
    # source: http://stackoverflow.com/a/5462069/192616
    class Namespace
      def initialize(hash)
        hash.each do |key, value|
          puts "adding a binding for #{key} => #{value}" if $LEITMOTIF_DEBUG
          singleton_class.send(:define_method, key) { value }
        end 
      end

      def get_binding
        binding
      end
    end
    
    def initialize(vars, options = nil)
      @options = DEFAULT_OPTIONS.merge((options || {}))
      @ns = Namespace.new(vars)
    end
  
    def process(template)
      vars = @ns.get_binding
      
      vars.untaint
      template.untaint
      
      # XXX: $SAFE level should be irrelevant here; only the supplied bindings should be available
      ERB.new(template, @options[:safe_level]).result(vars)
    end
  end

end # USE_ERUBIS