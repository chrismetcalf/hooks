#!/usr/bin/env ruby
#
# Webhook for turning a Slack message into an OmniFocus email

require 'json'
require 'net/smtp'
require 'pp'
require 'base64'
require 'net/http'

verbose = (ENV["VERBOSE"] == "true")

# Parse payload
payload = JSON.parse(ARGV.first)

message_ts = payload["message_ts"]

team = payload["team"]["domain"]
team_id = payload["team"]["id"]

user = payload["user"]["username"]
user_id = payload["user"]["id"]

channel = payload["channel"]["name"]
channel_id = payload["channel"]["id"]

text = payload["message"]["text"]

# Get a permalink
token = ENV["SLACK_TOKEN_#{team.upcase}"]
url = "https://slack.com/api/chat.getPermalink?token=#{token}&channel=#{channel_id}&message_ts=#{message_ts}"
response = JSON.parse(Net::HTTP.get(URI(url)))
permalink = response["permalink"] || "Error fetching permalink!"

# Send via email
hostname = ENV["SMTP_HOSTNAME"]
port = ENV["SMTP_PORT"]
sender_name = ENV["SENDER_NAME"]
sender = ENV["SENDER_EMAIL"]
recipient = ENV["RECIPIENT_EMAIL"]
smtp_username = ENV["SMTP_USERNAME"]
smtp_password = ENV["SMTP_PASSWORD"]

# Format our message
subject_raw = "@#{user} [#{team}/##{channel}] #{text}"
subject = "=?UTF-8?B?" + Base64.strict_encode64(subject_raw) + "?="

message = <<MESSAGE_END
Content-type: text/plain; charset=UTF-8
From: #{sender_name} <#{sender}>
To: #{recipient}
Subject: #{subject}

Permalink: #{permalink}

Team: slack://open?team=#{team_id}
Channel: slack://channel?id=#{channel_id}&team=#{team_id}
User: slack://user?id=#{user_id}&team=#{team_id}

#{text}
MESSAGE_END

if verbose
  puts message
end

smtp = Net::SMTP.new(hostname, port)
smtp.enable_starttls
smtp.start(hostname, smtp_username, smtp_password, :login)

# Try to send the message.
begin
  smtp.send_message(message, sender, recipient)
  puts "Email sent!"
rescue => e
  puts "Error sending email!"
  puts e
end
