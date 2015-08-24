#!/usr/bin/ruby
require 'benchmark'
require 'phantomjs'
require 'capybara'
require 'capybara/poltergeist'
require 'open-uri'
require 'optparse'

class PRRScraperConst
  RESULTS_URL = 'http://prracing.enmotive.com/results'
end

class PRRResultsScraper
  include Capybara::DSL

  attr_accessor :output_path
  
  def initialize(output_path)
    @output_path = output_path != nil ? output_path : "Results/"
  
    if ENV['IN_BROWSER']
      # On demand: non-headless tests via Selenium/WebDriver
      # To run the scenarios in browser (default: Firefox), use the following command line:
      # IN_BROWSER=true
      Capybara.default_driver = :selenium
    else
      # DEFAULT: headless tests with poltergeist/PhantomJS
      Capybara.register_driver :poltergeist do |app|
        Capybara::Poltergeist::Driver.new(
          app,
          window_size: [800, 600]#,
          #debug:       true
        )
      end
      Capybara.default_driver    = :poltergeist
      Capybara.javascript_driver = :poltergeist
    end
  end
  
  def is_uuid(uuid_string)
    return false if uuid_string.class != String
    
    uuid_components = uuid_string.downcase.scan(Regexp.new("^([0-9a-f]{8})-([0-9a-f]{4})-([0-9a-f]{4})-" + "([0-9a-f]{2})([0-9a-f]{2})-([0-9a-f]{12})$")).first
    
    return uuid_components == nil ? false : true
  end

  def navigate_to(url)
      visit url
  end
  
  def scrape
    Dir.mkdir(@output_path) unless Dir.exist?(@output_path)
    
    all('form#ResultIndexForm select#ResultsEventId option').each do |option|
      results_id = option.value
      if is_uuid(results_id)
        option.select_option
        
        results_heading = all('div#textResults h3').first
        return nil if results_heading == nil
        
        race_name = results_heading.text(:all)
        puts race_name
        
        results_link = all('div#textResults a').each do |a|
          puts "  #{a.text}: #{a[:href]}"

          results_file = File.join(@output_path, "[#{results_id}] #{race_name.gsub(/[\/\\:*?"<>|]/, '-')} - #{a.text.gsub(/[\/\\:*?"<>|]/, '-')}.htm")
          
          begin
            open(results_file, 'w') do |file|
              begin
                file << open(a[:href]).read
              rescue => e
                puts "Results not found for race: '#{option.text}' (#{option.value})"
              end
            end
          rescue => e
            puts "Failed to download results for race: '#{option.text}' (#{option.value})"
          ensure
            if File.exists?(results_file) && File.zero?(results_file)
              File.delete(results_file)
            end
          end
        end
        
      end
    end

    return self
  end
end

Options = Struct.new(:output)

class ArgvParser
  def self.parse(options)
    args = Options.new()

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: prr_results_scraper.rb [options]"

      opts.on("-oPATH", "--output=PATH", "Output directory path") do |o|
        args.output = o
      end

      opts.on("-h", "--help", "Prints help") do
        puts opts
        exit
      end
    end

    opt_parser.parse!(options)
    return args
  end
end

options = ArgvParser.parse(ARGV)

scraper = PRRResultsScraper.new(options.output)
scraper.navigate_to(PRRScraperConst::RESULTS_URL)
puts Benchmark.measure { scraper.scrape() }