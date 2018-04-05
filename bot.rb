#!/usr/bin/env ruby
require 'slack-ruby-client'
require 'celluloid/current'
require 'dotenv'
require 'oj'
Dotenv.load
Slack::RealTime.configure do |config|
  config.token = ENV['SLACK_API_TOKEN']
end

cards = Oj.load_file("data.json")["data"]["cards"]

class CommandHandler
  class Helper
    attr_accessor :data

    def initialize rt_client, data
      @rt_client = rt_client
      @data = data
    end

    def channel
      data['channel']
    end

    def reply text
      @rt_client.message(text: text, channel: data['channel'])
    end

    def web_reply **options
      @rt_client.web_client.chat_postMessage(**options.merge(channel: data['channel'], as_user: true))
    end
  end

  attr_accessor :rt_client

  def initialize cmd_prefix
    @cmd_prefix = cmd_prefix
    @rt_client = Slack::RealTime::Client.new
    @commands = {}

    @rt_client.on :message do |data|
      next unless data.has_key? "text"
      next unless data["text"].start_with? @cmd_prefix
      @commands.each do |pattern, behavior|
        if pattern =~ data["text"].sub(/^#{@cmd_prefix}/,"").strip
          behavior.call(Helper.new(@rt_client, data), $~)
          break
        end
      end
    end

  end

  def register pattern, &block
    @commands[pattern] = block
  end

  def start!
    @rt_client.start!
  end
end

bot = CommandHandler.new ""

clan_map = {
  0 => "중립",
  1 => "엘프",
  2 => "로얄",
  3 => "위치",
  4 => "드래곤",
  5 => "네크로맨서",
  6 => "뱀파이어",
  7 => "비숍",
  8 => "네메시스",
}

rarity_map = {
  1 => "브론즈",
  2 => "실버",
  3 => "골드",
  4 => "레전드",
}

char_type_map = {
  1 => "추종자",
  2 => "마법진",
  3 => "마법진",
  4 => "주문",
}

set_map = Hash.new("한정")

set_map[10000] = "기본 카드"
set_map[10001] = "CLC"
set_map[10002] = "DRK"
set_map[10003] = "ROB"
set_map[10004] = "TOG"
set_map[10005] = "WLD"
set_map[10006] = "SFL"
set_map[10007] = "CGS"
set_map[10008] = "DBN"

set_map[90000] = "토큰"

cards.reject!{|x| x["card_set_id"]/10000 == 7 }

name_map = cards.group_by{|x| x["card_name"].delete(" ,’'")}.map{|k,v| [k, v.first] }.to_h

bot.register /\[([^\[\]]+)\]/ do |helper, match|
  key = match[1].delete(" ,’'")
  next if key.length == 0
  c = name_map[key]
  unless c
    targets = cards.select{|x| x["card_name"].delete(" ,’'").include? key}
    if targets.length == 1
      c = targets.first
    end
  end
  if c
    repl =
    {
      author_name: "#{clan_map[c["clan"]]} #{rarity_map[c["rarity"]]} #{char_type_map[c["char_type"]]}",
      footer: set_map[c["card_set_id"]],
      title: "#{c["card_name"]} (#{c["cost"]})",
      color: "#2eb886",
      title_link: "https://shadowverse-portal.com/card/#{c["card_id"]}?lang=ko",
    }
    case c["char_type"]
    when 1
      repl.merge!(fields: [
        {
          title: "진화 전 (#{c["atk"]}/#{c["life"]})",
          short: true,
          value: "#{c["org_skill_disc"].gsub(/<br>/,"\n").gsub(/\[u\]\[ffcd45\]([^\[]+)\[-\]\[\/u\]/,'[*\1*]')}"
        },
        {
          title: "진화 후 (#{c["evo_atk"]}/#{c["evo_life"]})",
          short: true,
          value: "#{c["org_evo_skill_disc"].gsub(/<br>/,"\n").gsub(/\[u\]\[ffcd45\]([^\[]+)\[-\]\[\/u\]/,'[*\1*]')}"
        }
      ])
      helper.web_reply attachments: [
        repl,
        {
          title: "진화 전",
          image_url: "https://shadowverse-portal.com/image/card/ko/C_#{c["card_id"]}.png",
        },
        {
          title: "진화 후",
          image_url: "https://shadowverse-portal.com/image/card/ko/E_#{c["card_id"]}.png",
        }
      ]
    when 2,3,4
      repl.merge!(fields: [
        {
          value: "#{c["org_skill_disc"].gsub(/<br>/,"\n").gsub(/\[u\]\[ffcd45\]([^\[]+)\[-\]\[\/u\]/,'[*\1*]')}"
        }
      ],
      image_url: "https://shadowverse-portal.com/image/card/ko/C_#{c["card_id"]}.png")
      helper.web_reply attachments: [repl]
    end
  else
    case targets.length
    when 1
    when 2..10
      repl = targets.map { |c| {title: c["card_name"], title_link: "https://shadowverse-portal.com/card/#{c["card_id"]}?lang=ko"}}
      helper.web_reply text: "*#{match[1]}*: #{targets.length}개의 카드가 있습니다", attachments: repl
    else
      helper.reply "*#{match[1]}*: #{targets.length}개의 카드가 있습니다"
    end
  end

end


bot.start!

