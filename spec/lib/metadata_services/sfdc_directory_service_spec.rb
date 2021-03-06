require 'rspec'
require_relative "../../../lib/metadata_services/sfdc_directory_service"
require "zip"
require 'nokogiri'

describe 'Metadata::SfdcDirectoryService' do

  before(:all) do
    init_directory_service("test.salesforce.com")
  end

  before(:is_production => true) do
    init_directory_service("login.salesforce.com")
  end

  after(:all) do
    clean
  end

  describe "#write" do
    it "produces zip file" do
      expect(File.exists?(@temp_zip_filename)).to be_truthy
      expect(@temp_zip_filename).to include(".zip")
    end

    it "checks if package.xml exists" do
      expect(File.exists?(@path_package_xml)).to eq(true)
    end

    it "excludes files using exclude.yml" do
      expect(@zip_file.find_entry("classes/FileToExclude.cls")).to be_nil
      expect(@zip_file.find_entry("classes/FileToExclude.cls-meta.xml")).to be_nil
    end

    it "excluded directories using exclude.yml" do
      expect(@zip_file.find_entry("workflows/")).to be_nil
    end
  end

  describe "zip file" do
    it "contains file from source" do
      expect(@zip_file.find_entry("classes/DummyClass.cls")).to_not be_nil
      expect(@zip_file.find_entry("NOT_EXISTING_FILE")).to be_nil
    end

    it "contains directories from source" do
      expect(@zip_file.find_entry("classes/")).to_not be_nil
    end

    it "leaves package.xml intact" do
      expect(@zip_file.read("package.xml")).to include("<version>")
    end
  end

  describe "xml filter" do

    it "extracts xml snippet from file for sandbox" do
      doc = Nokogiri::XML(@zip_file.read('profiles/Admin.profile'))
      expect(doc.search("*//layoutAssignments/layout[starts-with('Social')]")).to be_empty
    end

    it "ignores exclude_xml for production", is_production: true do
      doc = Nokogiri::XML(@zip_file.read('profiles/Admin.profile'))
      expect(doc.search("*//layoutAssignments/layout[starts-with('Social')]")).to_not be_empty
    end

    it "saves original into file" do
      expect(@zip_file.read('profiles/Admin.profile')).to_not be_empty
    end
  end

  private

  def init_directory_service(deployment_host)
    @test_project_path = File.expand_path("../../../fixtures/TestProject", __FILE__)
    @exclude_component_path = File.expand_path("../../../fixtures/exclude_components.yml", __FILE__)
    @exclude_xml_path = File.expand_path("../../../fixtures/exclude_xml_nodes.yml", __FILE__)
    @args = {
        exclude_components: @exclude_component_path,
        exclude_xml: @exclude_xml_path,
        source: @test_project_path,
        host: deployment_host
    }
    @directory_service = Metadata::SfdcDirectoryService.new(@args)
    @path_package_xml = File.join(@test_project_path, "/project/src/package.xml")
    @temp_zip_filename = @directory_service.make_project_zip
    @zip_file = Zip::File.open(@temp_zip_filename)
  end

  def print_zip_content(zip_filename)
    Zip::File.foreach(zip_filename) do |entry|
      pp "==== #{entry}"
    end
  end

  def clean
    FileUtils.rm_rf @temp_zip_filename if File.exists?(@temp_zip_filename)
    @zip_file.close
  end
end
