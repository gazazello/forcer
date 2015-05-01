require "thor"
require_relative "./forcer/version"
require_relative "./utilities/action_options_service"
require_relative "./metadata_services/metadata_service"

module Forcer
  class ForcerMain < Thor
    class_option :dest, :aliases => :d, :desc => "Alias of destination sfdc org in your configuration.yml file. If you do not have configuration.yml in current directory, just skip the option."

    option :source, :aliases => :s, :desc => "Path to folder that contains 'src' directory somewhere. No restriction on exact 'src' location, except it should be somewhere in :sourse."
    option :checkOnly, :type => :boolean, :aliases => :c, :desc => "Only validates without actual deployment. Default is FALSE."
    option :rollbackOnError, :type => :boolean, :aliases => :b, :desc => "Rolls back whole deployment if error occurs. Default is TRUE."
    option :runAllTests, :type => :boolean, :aliases => :t, :desc => "Make all unit tests run. Default if FALSE. For production deployment it is always true."
    desc "deploy --dest destination_org_name", "Deploys project from local machine to destination org. Destination org" +
       " name should be specified in configuration.yml. Forcer asks for any information missing from configuration.yml"
    def deploy
      p "initiating DEPLOYMENT"
      all_options = verify_options(options)
      metadata = Metadata::MetadataService.new(all_options)
      metadata.deploy
    end


    # these section includes non-console methods to be used internally
    no_commands do
      def verify_options(old_options = {})
        p "verifying deployment information"
        new_options = ActionOptionsService.load_config_file(old_options)
        new_options[:host] ||=  "https://" + ask("Enter org url (test.salesforce.org or login.salesforce.org): ")
        new_options[:username] ||= ask("Enter username: ")
        new_options[:password] ||= ask("Enter password: ", :echo => false)
        new_options[:security_token] ||= ask("Enter security token: ")
        new_options[:source] ||= Dir.pwd
        new_options[:unit_test_running] = false
        operation = new_options[:checkOnly] ? "VALIDATION ONLY" : "DEPLOYMENT"
        p "===================="
        p "#{operation}   on => #{new_options[:dest].upcase}   as => #{new_options[:username]}"
        p "running all tests" if new_options[:runAllTests]
        p "===================="
        return new_options
      end
    end
  end
end
