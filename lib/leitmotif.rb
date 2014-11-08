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

$:.unshift File.dirname(__FILE__) # SKIP_FOR_STANDALONE

require 'fileutils'
require 'find'
require 'open3'
require 'yaml'

require 'instantiator' # SKIP_FOR_STANDALONE

module LMProcessHelpers
  
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

module LMPath
  def self.localPrototypeStore
    File.join(Dir.home, ".leitmotif-prototypes")
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
  
  def ensure_exists(path)
    unless File.exists?(path)
      FileUtils.mkdir_p(path)
    end
    path
  end
end

class PrototypeCreator
  DEFAULT_OPTIONS = {:git => "/usr/bin/git", 
      :verbose => false, 
      :debug => false, 
      :clobber => false,
      :local => false,
      :edit => false,
      :author => nil,
      :email => nil,
      :commit_message => "Initial revision"}
  
  include LMProcessHelpers
  include LMPath
  
  def initialize(name, options = nil)
    @options = DEFAULT_OPTIONS.merge(options || {})
    @options[:author] ||= spawn_and_capture(%W{#{@options[:git]} config --global user.name}).strip
    @options[:email] ||= spawn_and_capture(%W{#{@options[:git]} config --global user.email}).strip
    @name = name
    
    ensure_exists(LMPath::localPrototypeStore) if @options[:local]
  end
  
  def create()
    outputDir = @options[:local] ? File.join(LMPath::localPrototypeStore, @name) : @name
    check_output_dir(outputDir)
    ensure_exists(outputDir)
    
    oldcwd = Dir.getwd()
    Dir.chdir(outputDir)
    
    begin
      spawn_and_capture(%W{#{@options[:git]} init})
      o,e = spawn_with_input(make_history_file, %W{#{@options[:git]} fast-import})
      puts o if @options[:debug]
      puts e if @options[:debug]
      spawn_and_capture(%W{#{@options[:git]} checkout -b master refs/head/master})
      
      exec([ENV["EDITOR"],ENV["EDITOR"]], File.realpath(outputDir)) if @options[:edit]
    ensure
      Dir.chdir(oldcwd)
    end
    
    0
  end
  
  private
  
  def make_history_file()
    metadata = "---\n:name: #{@name}\n:version: '0'\n:required: []\n:ignore: []\n:defaults: {}\n"
    readme = "This is an empty Leitmotif prototype.  For details on how to set it up,\nplease see https://github.com/willb/leitmotif/wiki\n"
    ts = Time.now.strftime('%s %z')
    <<-eos
blob
mark :1
data #{metadata.length}
#{metadata}
blob
mark :2
data #{readme.length}
#{readme}
reset refs/head/master
commit refs/head/master
mark :3
author #{@options[:author]} <#{@options[:email]}> #{ts}
committer #{@options[:author]} <#{@options[:email]}> #{ts}
data #{@options[:commit_message].length}
#{@options[:commit_message]}
M 100644 :1 .leitmotif
M 100644 :2 proto/README
done

eos
  end
    
end

class LocalPrototypeStore
  DEFAULT_OPTIONS = {:git => "/usr/bin/git", 
      :verbose => false, 
      :clobber => false}
  
  def initialize(options = nil)
    @options = DEFAULT_OPTIONS.merge(options || {})
    @localps = LMPath::localPrototypeStore
    ensure_exists(@localps)
  end
  
  include LMProcessHelpers
  include LMPath
  
  def cloneProto(remoteURL)
    begin
      prototypeName = prototype_name(remoteURL)
      spawn_and_capture(%W{#{@options[:git]} clone #{remoteURL} "#{File.join(LMPath::localPrototypeStore, prototypeName)}"})
      0
    rescue Exception=>ex
      puts "error:  #{ex}"
      puts ex.backtrace.join("\n") if (@options[:verbose] || $LEITMOTIF_DEBUG)
      1
    end
  end
  
  def list()
    begin
      Dir[File.join(LMPath::localPrototypeStore, "*")].each do |proto|
        puts prototype_name(proto)
      end
      0
    rescue Exception=>ex
      puts "error:  #{ex}"
      puts ex.backtrace.join("\n") if (@options[:verbose] || $LEITMOTIF_DEBUG)
      1
    end
  end
  
  private
  def prototype_name(url)
    url.split("/").pop.gsub(".git", "")
  end
  
end

class Leitmotif
  DEFAULT_OPTIONS = {:git => "/usr/bin/git",
      :tar => "/usr/bin/tar", 
      :default_treeish => "master", 
      :verbose => false, 
      :clobber => false,
      :local => false}
  
  include LMPath

  def initialize(hash = nil, options = nil)
    @bindings = (hash || {}).dup
    @options = DEFAULT_OPTIONS.merge(options || {})
  end
  
  def run(prototype, outputDir)
    begin
      if @options[:local]
        prototype = File.join(LMPath::localPrototypeStore, prototype)
      end
      
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
    
    meta, archive = get_meta_and_proto(prototype, (@options[:ref] || @options[:default_treeish]))
    ymeta = YAML.load(meta)
    
    raise "#{prototype} doesn't look like a leitmotif prototype" unless (ymeta && list_proto(archive).size > 0)
    
    hash = (ymeta[:defaults] || {}).merge(@bindings).inject({}){|acc,(k,v)| acc[k.to_s] = v; acc}
    missing_required = (ymeta[:required] || []).select {|k| !hash.has_key?(k)}
    
    raise "prototype #{prototype} requires values for the following variables:  #{missing_required.join(", ")}" unless missing_required == []
    
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
 
  ### Needs clarifying. 
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
    metaArchive = spawn_and_capture(%W{#{@options[:git]} archive --remote #{remote} #{treeish} .leitmotif})
    meta, = spawn_with_input(metaArchive, %W{#{@options[:tar]} xO .leitmotif})
    meta
  end
  
  def get_proto(remote, treeish = nil)
    treeish ||= @options[:default_treeish]
    spawn_and_capture(%W{#{@options[:git]} archive --remote #{remote} #{treeish} proto})
  end
  
  def unpack_proto!(archive)
    spawn_with_input(archive, %W{#{@options[:tar]} x --strip 1})
  end
  
  def list_proto(archive)
    out, err = spawn_with_input(archive, %W{#{@options[:tar]} t})
    out.split("\n")
  end

  include LMProcessHelpers
end