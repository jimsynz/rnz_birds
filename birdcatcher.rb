#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'net/http'
require 'time'
require 'date'
require 'json'
require 'yaml'
require 'bitly'
require 'twitter'

bird_sounds = {
  "Takah\u0113" => 'Squawk! Squawk! Squawk!',
  "Riroriro" => "Wibble! Wibble! Wibble!",
  "Chaffinch" => "Twitter! Twitter!",
  "Hihi" => "Creak! Clack! Click!",
  "Kiwi" => "Oi! Oi! Oi!",
  "Kakapo" => "Oonst Oonst Oonst",
}

@config = YAML.load_file('config.yml')
Bitly.use_api_version_3
@bitly = Bitly.new(@config['bitly']['username'], @config['bitly']['api_key'])

i = 0
tweet_text = nil
until tweet_text
  i = i + 1
  uri = "/national/programmes/morningreport/birds-by-broadcast?result_1925413_result_page=#{i}"
  bird_doc = Net::HTTP.get 'www.radionz.co.nz', uri
  parsed_bird_doc = Nokogiri::HTML(bird_doc)

  bird_divs = parsed_bird_doc.css("div.bird")
  bird_divs.each do |bird_div|
    broadcast_date = Time.parse(bird_div.css('p').first.text.gsub('Broadcast date ',''))
    maori_name = bird_div.css("div[id^='content_div_'] > p > b").text
    pakeha_name = if match = bird_div.css("div[id^='content_div_'] > p").text.match(/.*\((.+)\).*/)
                    match[1].downcase
                  end
    mp3_url = bird_div.css('dl').css('dd[class="bird"]').css('a').last.attributes['href'].value

    shortened_mp3_url = @bitly.shorten(mp3_url).short_url
    if Date.today === broadcast_date.send(:to_date)
      tweet = []
      if bird_sounds[maori_name]
        tweet += "\"#{bird_sounds[maori_name]}\"".split(' ')
      end
      tweet << 'The'
      tweet << maori_name
      if pakeha_name
        tweet[-1] = "#{tweet[-1]};"
        tweet << "the"
        tweet << pakeha_name
      end
      tweet[-1] = "#{tweet[-1]}."
      tweet += "Radio New Zealand National.".split(' ')
      tweet << shortened_mp3_url if shortened_mp3_url
      tweet_text = tweet * " "
    end
  end
end

Twitter.configure do |config|
  config.consumer_key = @config['twitter']['consumer_key']
  config.consumer_secret = @config['twitter']['consumer_secret']
  config.oauth_token = @config['twitter']['oauth_token']
  config.oauth_token_secret = @config['twitter']['oauth_token_secret']
end

Twitter.update(tweet_text)
#puts tweet_text
