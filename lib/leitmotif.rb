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

$:.unshift File.dirname(__FILE__)

require 'fileutils'
require 'find'
require 'open3'

require 'instantiator'

class Leitmotif
  DEFAULT_OPTIONS = {:git => "/usr/bin/git", 
      :tar => "/usr/bin/tar", 
      :default_treeish => "master", 
      :verbose => false, 
      :clobber => false}
  
  def initialize(hash = nil, options = nil)
    @bindings = (hash || {}).dup
    @options = DEFAULT_OPTIONS.merge(options || {})
  end
  
  def run(prototype, outputDir)
    begin
      _run(prototype, outputDir)
    rescue Exception=>ex
      puts "error:  #{ex}"
      puts ex.backtrace.join("\n") if (@options[:verbose] || $LEITMOTIF_DEBUG)
      1
    end
  end
  
  private
  def _run(prototype, outputDir)
    check_output_dir(outputDir)
    
    meta, archive = get_meta_and_proto(prototype, @options[:default_treeish])
    ymeta = YAML.load(meta)
    
    raise "#{prototype} doesn't look like a leitmotif prototype" unless (ymeta && list_proto(archive).size > 0)
    
    hash = (ymeta[:defaults] || {}).merge(@bindings)
    ignore = (ymeta[:ignore] || [])
    
    FileUtils.mkdir_p(outputDir)
    oldcwd = Dir.getwd()
    Dir.chdir(outputDir)
    
    begin
      unpack_proto!(archive)
      instantiator = Instantiator.new(hash)
      
      Find.find(".") do |templateFile|
        if File.ftype(templateFile) == "file" && !ignore.member?(templateFile)
          oldFile = File.open(templateFile, "r") {|f| f.read}
          result = instantiator.process(oldFile)
          File.open(templateFile, "w") {|f| f.write(result)}
        end
      end
    ensure
      Dir.chdir(oldcwd)
    end
    0
  end
  
  def check_output_dir(outputDir)
    if File.exists?(outputDir)
      if @options[:clobber]
        FileUtils.rm_rf(outputDir)
      else
        raise "#{outputDir} already exists; move it first"
      end
    end
  end
  
  def get_meta_and_proto(remote, treeish = nil)
    meta = nil
    proto = nil
    
    begin
      treeish ||= @options[:default_treeish]
      meta = get_meta(remote, treeish)
      proto = get_proto(remote, treeish)
    rescue Exception=>ex
      raise "can't load leitmotif prototype and metadata: #{ex}"
    end
    
    [meta, proto]
  end
  
  def get_meta(remote, treeish = nil)
    treeish ||= @options[:default_treeish]
    metaArchive = spawn_and_capture(%Q{#{@options[:git]} archive --remote #{remote} #{treeish} .leitmotif})
    meta, = spawn_with_input(metaArchive, %Q{#{@options[:tar]} xO .leitmotif})
    meta
  end
  
  def get_proto(remote, treeish = nil)
    treeish ||= @options[:default_treeish]
    spawn_and_capture(%Q{#{@options[:git]} archive --remote #{remote} #{treeish} proto})
  end
  
  def unpack_proto!(archive)
    spawn_with_input(archive, %Q{#{@options[:tar]} x --strip 1})
  end
  
  def list_proto(archive)
    out, err = spawn_with_input(archive, %Q{#{@options[:tar]} t})
    out.split("\n")
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