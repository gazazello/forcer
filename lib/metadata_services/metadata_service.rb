require "savon"
require File.dirname(__FILE__) + "/project_directory_service.rb"

module Metadata
  class MetadataService

    API_VERSION = 33.0 # todo move to constants file
    attr_accessor :metadata_client, :current_session_id

    def initialize(target_dir_name = File.expand_path("./", __FILE__), args = {})
      # todo read credentials from yaml
      # todo check if target_dir_name exists
      # todo read endpoint_url from yaml
      @args = args
      @target_dir_name = target_dir_name
      @metadata_client = get_client
    end

    # lists metadata types like Classes, Pages
    def list
      default_list = ["CustomObject", "ApexClass", "ApexTrigger", "CustomLabels", "CustomTab", "EmailTemplate",
        "Profile", "Queue", "StaticResource", "ApexComponent", "ApexPage"]

      # assume components listed in terminal without commas as option to program
      if @args[:types] != nil
        types = @args[:types]
      elsif
        types = default_list
      end

      queries = ""
      types.each do |type|
        queries += "<met:type>#{type.to_s}</met:type><met:folder>#{type.to_s}</met:folder>"
      end

      list_metadata_request = File.read(File.dirname(__FILE__) + "/list_metadata_request.xml")
      xml_param = list_metadata_request % [@current_session_id, queries, API_VERSION]
      @metadata_client.call(:list_metadata, :xml => xml_param)
    end

    def deploy
      dir_zip_service = ProjectDirectoryService.new(@target_dir_name)
      zip_name = dir_zip_service.write
      blob_zip = Base64.encode64(File.open(zip_name, "rb").read)

      # todo read options from console arguments
      options = {
        singlePackage: true,
        rollbackOnError: true,
        checkOnly: true,
        allowMissingFiles: false,
        runAllTests: false,
        ignoreWarnings: false
      }

      # prepare xml for deployment
      deploy_options_snippet = ""
      options.each do |k, v|
        key = k.to_s
        val = v.to_s
        # todo take care of array options
        deploy_options_snippet += "<met:#{key}>#{val}</met:#{key}>"
      end

      debug_options_snippet = "" #by default no debug options

      deploy_request_xml = File.read(File.dirname(__FILE__) + "/deploy_request.xml");
      xml_param = deploy_request_xml % [debug_options_snippet, @current_session_id, blob_zip, deploy_options_snippet]
      response = @metadata_client.call(:deploy, :xml => xml_param)
      if response.body[:deploy_response][:result] == "Queued"
        p "DEPLOYMENT FAILED. CHECK DEPLOYMENT STATUS LOG IN SALESFORCE ORG."
      else
        p "DEPLOYMENT STARTED. CHECK DEPLOYMENT STATUS IN SALESFORCE ORG."
      end
    ensure
      FileUtils.rm_f zip_name

    end

    private
    def login
      endpoint_url = @args[:host]
      options = {
        endpoint: "#{endpoint_url}/services/Soap/c/#{API_VERSION}",
        wsdl: File.expand_path("../enterprise.wsdl", __FILE__),
        :headers => {
          "Authentication" => "secret"
        }
      }
      enterprise_client = Savon.client(options)

      message = {
        username: @args[:username],
        password: "#{@args[:password]}#{@args[:security_token]}"
      }

      # === login
      response = enterprise_client.call(:login, message: message)
      # p "login response : #{response}"
      @current_session_id = response.body[:login_response][:result][:session_id]
      @metadata_server_url = response.body[:login_response][:result][:metadata_server_url]
    end

    def get_client
      login
      options = {
        wsdl: File.expand_path("../metadata.wsdl", __FILE__),
        endpoint: @metadata_server_url,
        soap_header: {
          "tns:SessionHeader" => {
            "tns:sessionId" => @current_session_id
          }
        },
        read_timeout: 60 * 10,
        open_timeout: 60 * 10
      }
      return Savon.client(options)
    end

  end # class MetadataService
end # module Metadata

# test area

  # args = {
  #   host: "https://test.salesforce.com",
  #   username: "gaziz@eventbrite.com.comitydev",
  #   password: "?kMMTR[d}X7`Fd}>@T.",
  #   security_token: "fpX1t6k2We39Qtq42NKbnLWSQ"
  # }
  # metadata_service = Metadata::MetadataService.new(
  #   File.expand_path("../../../tmp/TestProject", __FILE__),
  #   args
  # )
  #
  # p metadata_service.list.body
# p metadata_service.deploy
