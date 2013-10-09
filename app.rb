# Require the bundler gem and then call Bundler.require to load in all gems
# listed in Gemfile.
require 'bundler'
Bundler.require

require 'json'
require 'zip'

# Class for showing IDML file's raw source
class IdmlStorySources

  # Initializes an instance of self
  # @param[File] idml_file
  def initialize(idml_file)
    @idml_file = idml_file
    read_story_filenames
  end

  # Returns array of story sources
  def to_a
    @stories.keys.map { |e| get_stories(e).to_s }
  end

  def read_story_filenames
    @stories = {}
    Zip::File.open(@idml_file.path, false) do |zip|
      data = zip.get_entry('designmap.xml').get_input_stream.read
      xml = Nokogiri::XML(data) {|cfg| cfg.noblanks}
      xml.xpath('/Document/idPkg:Story').each do |story|
        story_file = story['src']
        story_data = zip.get_entry(story_file).get_input_stream.read
        story_xml = Nokogiri::XML(story_data) {|cfg| cfg.noblanks}
        story_xml.xpath('/idPkg:Story/Story').each do |s|
          @stories[s['Self']] = story_file
        end
      end
    end
  end

  def get_stories(name)
    Zip::File.open(@idml_file.path, false) do |zip|
      story_data = zip.get_entry(@stories[name]).get_input_stream.read
      story_xml = Nokogiri::XML(story_data) {|cfg| cfg.noblanks}
      story_xml.xpath('/idPkg:Story/Story')
    end
  end

end

# Root URL with some help text
get '/' do
  erb :index
end

post '/upload' do
  unless(
    params[:file] &&
    (tmpfile = params[:file][:tempfile]) &&
    (@idml_file_name = params[:file][:filename])
  )
    @error = "Please select a file to upload."
    return erb :index
  end
  @idml_story_sources = IdmlStorySources.new(tmpfile).to_a
  @highlit_story_sources = @idml_story_sources.map { |e|
    CodeRay.scan(e, :xml).div(:line_numbers => :table, :css => :class)
  }
  erb :show_source
end
