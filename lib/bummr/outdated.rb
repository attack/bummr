require 'open3'
require 'singleton'

module Bummr
  class Outdated
    include Singleton

    def outdated_gems(options = {})
      results = []
      skip = options[:skip] || []

      bundle_options =  ""
      bundle_options << " --strict" unless options[:all_gems]
      bundle_options << " --group #{options[:group]}" if options[:group]

      Open3.popen2("bundle outdated" + bundle_options) do |_std_in, std_out|
        while line = std_out.gets
          puts line
          gem = parse_gem_from(line)

          puts "DEBUG: outdated"
          puts "  gem: #{gem}"
          puts "  skip: #{skip}"
          puts "  include?: #{!skip.include?(gem[:name])}" if gem
          if gem && !skip.include?(gem[:name]) && (options[:all_gems] || gemfile_contains(gem[:name]))
            results.push gem
          else
            puts "DEBUG: skipping: #{gem}"
          end
        end
      end

      results
    end

    def parse_gem_from(line)
      regex = / \* (.*) \(newest (\d[\d\.]*\d)[,\s] installed (\d[\d\.]*\d)[\),\s]/.match line

      unless regex.nil?
        { name: regex[1], newest: regex[2], installed: regex[3] }
      end
    end

    private

    def gemfile_contains(gem_name)
      /gem ['"]#{gem_name}['"]/.match gemfile
    end

    def gemfile
      @gemfile ||= `cat Gemfile`
    end
  end
end
