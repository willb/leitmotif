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

if USE_ERUBIS

  require 'erubis'

  class Instantiator
    def initialize(hash)
      @vars = hash.dup
    end

    def process(input)
      Erubis::Eruby.new(template).result(@vars)
    end
  end

else # USE_ERUBIS

  require 'erb'

  class Instantiator
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
    
    def initialize(vars)
      @ns = Namespace.new(vars)
    end
  
    def process(template)
      ERB.new(template).result(@ns.get_binding)
    end
  end

end # USE_ERUBIS