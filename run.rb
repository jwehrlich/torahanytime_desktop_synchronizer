#!/usr/bin/env ruby
require 'optparse'
require 'net/http'
require 'json'
require 'mp3info'
require 'fileutils'
require 'date'

# Base class for connecting to internet
class Connectable
  def post_request(url, params = [])
    uri = URI(url)
    response = Net::HTTP.post_form(uri, params)
    raise 'post request failed' unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  end

  def download_file(url, file_path)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    resp = http.get(uri.path)

    FileUtils.mkdir_p File.dirname(file_path)
    open(file_path, 'wb') do |file|
      file.write(resp.body)
    end
  end
end

# TorahAnyting.com Speaker
class Speaker < Connectable
  attr_reader :id, :name, :image, :lectures
  DEFAULT_OFFSET = 0
  DEFAULT_LIMIT = 100

  def initialize(payload)
    @id = payload['speaker_id']
    @name = "#{payload['name_first']} #{payload['name_last']}"
    @image = load_speaker_image(payload['photo'])
    @lectures = load_lectures
  end

  private

  def load_speaker_image(file_name)
    url = "https://files.torahanytime.com/flash/speakers/#{file_name}"
    dir = './tmp'
    FileUtils.mkdir_p(dir)

    file_path = "#{dir}/#{file_name}"
    download_file(url, file_path) unless File.exist?(file_path)
    File.new(file_path, 'rb').read
  end

  def load_lectures
    url = 'https://www.torahanytime.com/n/list'
    params = [
      %w(l lectures),
      %w(t all),
      ['o', DEFAULT_OFFSET],
      ['f', "{\"speaker\":#{@id}}"],
      ['limit', DEFAULT_LIMIT]
    ]
    response = post_request(url, params)['items']
    response.collect { |lecture| Lecture.new(self, lecture) }
  end
end

# TorahAnytime.com Lecture
class Lecture < Connectable
  attr_reader :id, :name, :date
  def initialize(speaker, payload)
    @speaker = speaker
    @id = payload[0]
    @name = payload[1]
    @date = payload[3]
    @length = payload[4]
  end

  def download(user_id, path)
    FileUtils.mkdir_p(path)
    file_path = "#{path}/#{@speaker.name.downcase.tr(' ', '_')}/#{file_name}"
    if File.exist?(file_path)
      puts "Already downloaded file: #{file_name}"
    else
      puts "Downloading: #{file_name}..."
      url = download_url(user_id)
      download_file(url, file_path)
      process_mp3_metadata(file_path)
    end
  end

  def file_name
    return @file_name unless @file_name.nil?

    speaker_name = @speaker.name.downcase.tr(' ', '_')
    title = @name.downcase.tr(' ', '_')
    time = "#{date_as_parts[2]}-#{date_as_parts[0]}-#{date_as_parts[1]}"
    @file_name = "#{speaker_name}-#{time}-#{title}.mp3".gsub(%r{^.*(\\|\/)}, '')
                                                       .gsub(/[^0-9A-Za-z.\-]/, '_')
  end

  private

  def date_as_parts
    return @parts unless @parts.nil?

    parts = date.split('/')
    @parts = if parts.count == 3
               times
             elsif parts.count == 1
               parts = date.split('-')
               [parts[1], parts[2], parts[0]]
             else
               []
             end
  end

  def download_url(user_id)
    url = 'https://www.torahanytime.com/u/download'
    params = [
      ['uniqid', user_id],
      ['v', @id]
    ]
    post_request(url, params)['link']
  end

  def process_mp3_metadata(file_path)
    puts 'Updating MP3 metadata'
    Mp3Info.open(file_path) do |mp3|
      time = "#{date_as_parts[2]}-#{date_as_parts[0]}-#{date_as_parts[1]}"
      year = date_as_parts[2]
      month = ::Date::MONTHNAMES[date_as_parts[0].to_i]
      mp3.tag.title = "(#{time}) #{@name}"
      mp3.tag.artist = @speaker.name
      mp3.tag.album = "TorahAnytime.com - #{@speaker.name} - #{month} #{year}"
      mp3.tag.year = @date.split('/')[2]
      mp3.tag.comments = "Lecture was given on: #{@date}"
      mp3.tag2.add_picture(@speaker.image, mime: 'jpeg', pic_type: 3)
    end
  end
end

# Putting it all together to download classes from speakers user is following
class TorahAnytimeUpdates < Connectable
  DEFAULT_DOWNLOAD_PATH = './lectures'.freeze

  def run(options)
    @user_id = options['user_id']
    @download_path = options['path'] || DEFAULT_DOWNLOAD_PATH

    speakers.each do |speaker|
      process_speaker(speaker)
    end
  end

  def speakers
    url = 'https://www.torahanytime.com/u/get_user_followings'
    params = [['uniqid', @user_id]]
    response = post_request(url, params)
    response.collect { |speaker| Speaker.new(speaker) }
  end

  def process_speaker(speaker)
    puts "Processing Speaker with id: #{speaker.id}..."
    puts "Processing #{speaker.lectures.count} classes..."
    speaker.lectures.each do |lecture|
      lecture.download(@user_id, @download_path)
    end
  end
end

def help_menu_and_exit
  puts <<-"EOHELP"
Update TorahAnytime Lectures:

Usage: bundle exec ruby #{__FILE__} [--help]

OPTIONS
--path : Path to download lectures to
--user_id : TorahAnytime.com user id
--help : help

EOHELP
  exit(0)
end

if File.expand_path($PROGRAM_NAME) == File.expand_path(__FILE__)
  options = {}
  parser = OptionParser.new do |opts|
    opts.on('-p', '--path path') do |path|
      options['path'] = path
    end

    opts.on('-u', '--user_id user_id') do |user_id|
      options['user_id'] = user_id
    end

    opts.on('-h', '--help', 'help menu') do
      help_menu_and_exit
    end
  end

  begin
    parser.parse!
  rescue
    help_menu_and_exit
  end

  TorahAnytimeUpdates.new.run(options)
end
