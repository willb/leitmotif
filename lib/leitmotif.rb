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

require 'fileutils'
require 'find'
require 'open3'

class Leitmotif
  DEFAULT_OPTIONS = {:git => "/usr/bin/git", :tar => "/usr/bin/tar", :treeish => "master"}
  
  def initialize(hash = nil, options = nil)
    @bindings = (hash || {}).dup
    @options = DEFAULT_OPTIONS.merge(options || {})
  end
  
  def run(template, outputDir)
    begin
      _run(template, outputDir)
    rescue Exception=>ex
      puts "fatal error:  #{ex}"
      puts ex.backtrace.join("\n")
      1
    end
  end
  
  def _run(template, outputDir)
    metaFile = File.join(template, ".leitmotif")
    meta = File.exists?(metaFile) && YAML.load_file(metaFile)
    
#    raise "#{template} doesn't look like a leitmotif prototype" unless (meta && File.directory?(proto))
    raise "#{outputDir} already exists; move it first" if (File.exists?(outputDir))
    
    defaults = @bindings.merge(meta[:defaults] || {})
    
    archive = get_proto(template, @options[:treeish])
    
    FileUtils.mkdir_p(outputDir)
    oldcwd = Dir.getwd()
    Dir.chdir(outputDir)
    
    begin
      spawn_with_input(archive, %q{tar x --strip 1})
      
      Find.find(".") do |templateFile|
        basename = templateFile
      end
    ensure
      Dir.chdir(oldcwd)
    end
    0
  end
  
  def get_meta(remote, treeish = nil)
    treeish ||= @options[:treeish]
    metaArchive = spawn_and_capture(%Q{#{@options[:git]} archive --remote #{remote} #{treeish} .leitmotif})
    meta, = spawn_with_input(metaArchive, %Q{#{@options[:tar]} xO .leitmotif})
    meta
  end
  
  def get_proto(remote, treeish = nil)
    treeish ||= @options[:treeish]
    spawn_and_capture(%Q{#{@options[:git]} archive --remote #{remote} #{treeish} proto})
  end
  
  def spawn_and_capture(*cmd)
    Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
      exit_status = wait_thr.value
      raise "command '#{cmd.inspect}' failed; more details follow:  #{stderr.read}" unless exit_status == 0
      stdout.read
    end
  end
  
  def spawn_with_input(str, *cmd)
    out, err, s = Open3.capture3(*cmd, :stdin_data=>str)
    raise "command '#{cmd.inspect}' failed; more details follow:  #{err}" unless s.exitstatus == 0
    [out, err]
  end
end