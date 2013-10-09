# Require the bundler gem and then call Bundler.require to load in all gems
# listed in Gemfile.
require 'bundler'
Bundler.require

require 'json'
require 'zip'

# Class for showing IDML file's raw source
class IdmlStories

  # Initializes an instance of self given an idml_file
  # @param[File] idml_file
  def initialize(idml_file)
    @idml_file = idml_file
    read_story_filenames
  end

  # Returns array of story objects
  # @return[Array<OpenStruct>] See #get_story for details.
  def stories
    @stories.keys.each_with_index.map { |story_name, i| get_story(story_name, i) }
  end

  # Extracts the story filenames from @idml_file into the @stories hash
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

  # Returns a story object with the following properties:
  #     * name
  #     * body (raw xml source)
  #     * body_as_html (xml source with html syntax highlighting)
  #     * length - number of characters in body
  def get_story(name, index)
    body = Zip::File.open(@idml_file.path, false) do |zip|
      story_data = zip.get_entry(@stories[name]).get_input_stream.read
      story_xml = Nokogiri::XML(story_data) {|cfg| cfg.noblanks}
      story_xml.xpath('/idPkg:Story/Story').to_s
    end
    OpenStruct.new(
      :name => name,
      :body => body,
      :body_as_html => CodeRay.scan(body, :xml) \
                              .div(
                                :line_numbers => :table,
                                :css => :class,
                                :line_number_anchors => "story_#{ index+1 }_line_"
                              ),
     :length => body.length
    )
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
  @idml_stories = IdmlStories.new(tmpfile).stories
  erb :show_source
end
