require 'rubygems'
require 'rtranslate'

module Translator
  module Support
    # Mapping of the way Yahoo! Mail represents country codes with the way Google Translate does.
    #
    # The key is the Yahoo! Mail representation, and the value is the code Google Translate would expect.
    #
    LOCALES = {
      "de-DE" => "de",
      "en-MY" => "en",
      "en-SG" => "en",
      "es-MX" => "es",
      "it-IT" => "it",
      "vi-VN" => "vi",
      "zh-Hant-TW" => "zh-TW",
      "en-AA" => "en",
      "en-NZ" => "en",
      "en-US" => "en",
      "fr-FR" => "fr",
      "ko-KR" => "ko",
      "zh-Hans-CN" => "zh-CN",
      "en-AU" => "en",
      "en-PH" => "en",
      "es-ES" => "es",
      "id-ID" => "id",
      "pt-BR" => "PORTUGUESE",
      "zh-Hant-HK" => "zh-CN",
    }
  end
  
  #
  # Finds English language translation keys which have not been translated 
  # and translates them through Google Translate.
  #
  # Usage: 
  #   Translator::Yaml.new(:source => 'en.yml', :destination => 'output.yml).translate
  #
  class Base
    include Translator::Support
    
    def self.template
      raise "Define in child"
    end
    
    # instance methods
    
    attr_accessor :source, :destination
  
    def initialize(options={})
      @source = options[:source]
      @destination = options[:destination]
    end
    
    def translate
      copy_lines_to_all_locales
    end
    
    def non_english_locales
      @non_english_locales ||= LOCALES.select do |lang, code|
        lang !~ /^en/
      end
    end
    
    def non_us_locales
      @non_us_locales ||= LOCALES.select do |lang, code|
        lang != "en-US"
      end
    end

    def copy_lines_to_all_locales
      write_content(destination, new_translation_message)
      non_us_locales.each do |lang, code|
        new_content = each_line do |line|
          copy_and_translate_line(line, lang)
        end
        write_content(destination, new_content)
        clear_all_keys
      end
    end
    
    def write_content(destination, content)
      if content && content.strip != ""
        puts content
        puts
        File.open(destination, "a") do |f|
          f.puts
          f.puts content
        end
      end        
    end
    
    def new_translation_message
      now = Time.now
      
      date = now.day
      month = now.month
      year = now.year
      
      timestamp = "#{month}/#{date}/#{year}"
      output = []
      output << "# "
      output << "# Keys translated automatically on #{timestamp}."
      output << "# "
      
      output.join("\n")
    end
    
    def each_line
      output = []
      File.open(source, "r") do |f|
        f.readlines.each do |line|
          new_line = yield line
          output << new_line
        end
      end
      output.flatten.join("\n")
    end
    
    def all_keys(lang)
      unless @all_keys
        @all_keys = {}
        Dir["#{language_path(lang)}/#{all_source_files}"].each do |p|
          @all_keys = @all_keys.merge(parse_template(p))
        end
      end
      @all_keys
    end
    
    def self.all_source_files
      raise "Define in child"
    end
    
    def parse_template(p)
      raise "Define in child"
    end
    
    def clear_all_keys
      @all_keys = nil
    end
  
    def copy_and_translate_line(line, lang)
      line = line.split("\n").first
      if comment?(line) || line.strip == ""
        nil
      else
        translate_new_key(line, lang)
      end
    end
    
    def translate_new_key(line, lang)
      k, v = key_and_value_from_line(line)
      if k
        if k == "en"
          format(lang, "")
        else
          if v.strip == ""
            format(k, "")
          else
            format(k, translate_key(v, lang))
          end
        end
      else
        nil
      end        
    end
    
    def translate_key(value, lang)
      code = LOCALES[lang]
      value = pre_process(value, lang)
      translation = Translate.t(value, "ENGLISH", code)
      post_process(translation, lang)
    end
    
    def pre_process(value, lang)
      value
    end
    
    def post_process(value, lang)
       if lang =~ /zh/
        value.gsub!("<strong>", "")
        value.gsub!("</strong>", "")
      end
      
      value.gsub!(/^#{194.chr}#{160.chr}/, "")
      
      value.gsub!(" ]", "]")
      value.gsub!("«", "\"")
      value.gsub!("»", "\"")
      value.gsub!(/\"\.$/, ".\"")
      value.gsub!(/\\ \"/, "\\\"")
      value.gsub!(/<\/ /, "<\/")
      value.gsub!(/(“|”)/, "\"")
      value.gsub!("<strong> ", "<strong>")
      value.gsub!(" </strong>", "</strong>")
      value.gsub!("&quot;", "\"")
      value.gsub!("&#39;", "\"")
      value.gsub!("&gt; ", ">")
      
      value.gsub!("\"", "'")
      value.gsub!(/^\'/, "\"")
      value.gsub!(/\'$/, "\"")
      value.gsub!(" \"O", " \\\"O")
        
      value.gsub!(/\((0)\)/, "{0}")
      value.gsub!(/\((1)\)/, "{1}")
      value.gsub!(/\((2)\)/, "{2}")
      value.gsub!("（0）", "{0}")
      
      unless value =~ /\"$/
        value = "#{value}\""
      end
      unless value =~ /^\"/
        value = "#\"{value}"
      end
      
      value.strip
    end
    
    def format(key, value)
      raise "Define in child"
    end
    
    def key_and_value_from_line(line)
      raise "Define in child"
    end
  
    def comment?(line)
      raise "Define in child"
    end    
  end
  
  class Yaml < Base
    def self.template
      Yaml
    end
    
    def parse_template(path)
      YAML.load_file(path)
    end
    
    def format(key, value)
      "#{key}: #{value}"
    end
    
    def key_and_value_from_line(line)
      if line =~ /^([^\:]+):(.*)/
        return $1, $2.strip
      else
        return nil, nil
      end
    end
  
    def comment?(line)
      line =~ /^#/
    end
  end
end
