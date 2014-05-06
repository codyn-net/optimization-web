#!/usr/bin/ruby

require 'erb'
require 'optparse'
require 'fileutils'
require 'rubygems'
require 'kramdown'
require 'cgi'

class Context
    attr_reader :vars

    def initialize(vars = {})
        @vars = vars

        @vars.each do |key, value|
            instance_variable_set("@#{key}", value)

            metaclass = class << self; self; end

            metaclass.class_eval do
                attr_reader key.to_sym
            end
        end
    end

    def var(name, defval = nil)
        instance_variable_get("@#{name}") or defval
    end

    def context
        binding
    end

    def merge(vars = {})
        Context.new(@vars.merge(vars))
    end

    def template(filename, vars = {}, &block)
        templ = ERB.new(File.read(filename), nil, nil, '@_erout')

        if block_given?
            before = @_erout.length

            ret = yield

            after = @_erout.length

            vars[:contents] = @_erout[before..after]
            @_erout[before..after] = ''

            return @engine.context(vars) do |ctx|
                @_erout += templ.result(ctx.context)
            end
        end

        return @engine.context(vars) do |ctx|
            templ.result(ctx.context)
        end
    end

    def image(filename, caption)
        caption = CGI.escapeHTML(caption)

        @_erout += '<div class="image-container"><div class="image"><img src="images/' + CGI.escapeHTML(filename) + '" alt="' + caption + '"><div class="caption">' + caption + '</div></div></div>'
    end

    def markdown
        before = @_erout.length

        ret = yield

        after = @_erout.length

        opts = {
            :toc_levels => "1,2"
        }

        @_erout[before..after] = Kramdown::Document.new(@_erout[before..after], opts).to_html
    end

    def input(filename)
        File.read(filename)
    end
end

class Engine
    def self.run(files, outputdir, vars = {})
        FileUtils.mkdir_p(outputdir)

        files.each do |f|
            engine = Engine.new(f, outputdir)
            engine.process(vars)
        end
    end

    def initialize(filename, outputdir)
        @filename = filename
        @outputdir = outputdir
        @vars = {}
        @contexts = []
    end

    def current_context
        @contexts.last
    end

    def push_context(vars = {})
        if @contexts.empty?
            @contexts << Context.new(vars)
        else
            @contexts << current_context.merge(vars)
        end

        current_context
    end

    def pop_context
        @contexts.delete_at(@contexts.length - 1) unless @contexts.empty?
    end

    def context(vars = {})
        ctx = push_context(vars)

        ret = yield ctx

        pop_context

        return ret
    end

    def process(vars)
        ret = context(vars.merge({:engine => self})) do |ctx|
            ctx.template(@filename)
        end

        # Write it
        outfile = File.join(@outputdir, @filename)
        FileUtils.mkdir_p(File.dirname(outfile))

        File.new(outfile, 'w').write(ret)
    end
end

$options = {:output => 'generated', :static => [], :force => false}

OptionParser.new do |opts|
    opts.banner = "Usage: process.rb [$options] FILES"

    opts.on("-o DIR", "--output DIR", "Output directory") do |o|
        $options[:output] = o
    end

    opts.on("-s FILE", "--static FILE", "Static files to copy") do |s|
        $options[:static] << s
    end

    opts.on("-f", "--force", "Force overriding existing files") do
        $options[:force] = true
    end
end.parse!

exist = File.exist?($options[:output])

if exist and not $options[:force]
    STDOUT.write("The output directory `#{$options[:output]}' already exists, remove? [y]es/[c]ancel: ")

    system("stty raw -echo")
    c = STDIN.getc
    system("stty -raw echo")
    STDOUT.puts

    case c
        when ?c
            exit 1
    end
end

if exist
    FileUtils.rm_r($options[:output])
end

Engine.run(ARGV, $options[:output])

def link(filename, dest)
    return if ['..', '.'].include?(File.basename(filename))

    FileUtils.mkdir_p(dest)

    if File.directory?(filename)
        if not filename.end_with?('/')
            dest = File.join(dest, File.basename(filename))
            FileUtils.mkdir_p(dest)
        end

        Dir.entries(filename).each do |entry|
            link(File.join(filename, entry), dest)
        end
    else
        destfile = File.join(dest, File.basename(filename))

        exist = File.exist?(destfile)

        if exist and not $options[:force]
            while true
                STDOUT.write("The file `#{destfile}' already exists, override? [y]es/[n]o/[a]ll/[c]ancel: ")

                system("stty raw -echo")
                c = STDIN.getc
                system("stty -raw echo")
                STDOUT.puts

                case c
                    when ?y
                        break
                    when ?n
                        return
                    when ?a
                        $options[:force] = true
                        break
                    when ?c
                        exit 1
                end
            end
        end

        if exist
            File.unlink(destfile)
        end

        FileUtils.ln(filename, dest)
    end
end

# Copy static files
$options[:static].each do |item|
    link(item, $options[:output])
end

# vi:ex:ts=4:et
