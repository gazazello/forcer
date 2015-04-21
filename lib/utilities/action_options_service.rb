require "yaml"

module Forcer
  class ActionOptionsService

    # attempts to read salesforce org information from yaml
    def self.load_config_file(old_options = {})
      options = old_options.clone

      config_file_path = File.join(Dir.pwd, "/configuration.yml")
      return options unless File.exists?(config_file_path)

      dest = options[:dest]
      configuration = YAML.load_file(config_file_path).to_hash

      return options if configuration[dest].nil?

      configuration[dest].each do |key, value|
        options.store(key.to_sym, value.to_s)
      end
      options[:dest_url] = "https://#{options[:dest_url]}" unless options[:dest_url].include?("http")

      return options
    end

  end
end