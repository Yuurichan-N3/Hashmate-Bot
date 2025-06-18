require 'httparty'
require 'json'
require 'uri'
require 'colorize'

def load_init_data
  unless File.exist?('data.txt')
    puts "File data.txt not found!".red.bold
    exit(1)
  end
  File.readlines('data.txt').map(&:strip).reject(&:empty?)
end

def get_username(init_data)
  begin
    decoded = URI.decode_www_form_component(init_data)
    user_json = decoded.split('user=')[1].split('&')[0]
    user_data = JSON.parse(user_json)
    user_data['first_name'] || 'Unknown'
  rescue
    'Unknown'
  end
end

def log(message, color)
  case color
  when 'red'
    puts message.red.bold
  when 'green'
    puts message.green.bold
  when 'yellow'
    puts message.yellow.bold
  when 'purple'
    puts message.magenta.bold
  when 'cyan'
    puts message.cyan.bold
  when 'bold'
    puts message.bold
  else
    puts message.bold
  end
end

def login(init_data)
  url = 'https://api.hashmate-bot.com/v1/authorization/login'
  headers = {
    'content-type' => 'application/json',
    'user-agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36 Edg/137.0.0.0'
  }
  payload = { 'initData' => init_data }
  begin
    response = HTTParty.post(url, headers: headers, body: payload.to_json)
    if response.code == 200
      data = JSON.parse(response.body)
      username = get_username(init_data)
      log("Login successful for #{username}", 'green')
      data['accessToken']
    else
      username = get_username(init_data)
      log("Login failed for #{username}", 'red')
      nil
    end
  rescue StandardError => e
    username = get_username(init_data)
    log("Error during login for #{username}", 'red')
    nil
  end
end

def select_mining(token, access_token)
  url = 'https://api.hashmate-bot.com/v1/mining/switch'
  headers = {
    'content-type' => 'application/json',
    'authorization' => "Bearer #{access_token}",
    'user-agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36 Edg/137.0.0.0'
  }
  payload = { 'token' => token }
  begin
    response = HTTParty.post(url, headers: headers, body: payload.to_json)
    if response.code == 201
      log("Successfully selected token #{token}", 'purple')
      true
    else
      log("Failed to select token #{token}", 'red')
      false
    end
  rescue StandardError => e
    log("Error while selecting token #{token}", 'red')
    false
  end
end

def start_mining(access_token)
  url = 'https://api.hashmate-bot.com/v1/mining/start'
  headers = {
    'content-type' => 'application/json',
    'authorization' => "Bearer #{access_token}",
    'user-agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36 Edg/137.0.0.0'
  }
  payload = { 'durationInMinutes' => 30 }
  begin
    response = HTTParty.post(url, headers: headers, body: payload.to_json)
    if response.code == 201
      log('Mining started', 'green')
      true
    else
      log('Failed to start mining', 'red')
      false
    end
  rescue StandardError => e
    log('Error while starting mining', 'red')
    false
  end
end

def reset_mining(access_token)
  url = 'https://api.hashmate-bot.com/v1/mining/reset'
  headers = {
    'content-type' => 'application/json',
    'authorization' => "Bearer #{access_token}",
    'user-agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36 Edg/137.0.0.0'
  }
  begin
    response = HTTParty.post(url, headers: headers)
    if response.code == 201
      log('Mining reset', 'yellow')
      true
    else
      log('Failed to reset mining', 'red')
      false
    end
  rescue StandardError => e
    log('Error while resetting mining', 'red')
    false
  end
end

def display_countdown(seconds)
  while seconds > 0
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60
    log("Waiting for reset: #{format('%02d:%02d:%02d', hours, minutes, secs)}", 'bold')
    sleep(1)
    seconds -= 1
    print "\033[1A\033[K"
  end
end

STDOUT.write "\e]2;Hashmate by : 佐賀県産 （𝒀𝑼𝑼𝑹𝑰）\a"

def main
  banner = <<~BANNER
    ╔══════════════════════════════════════════════╗
    ║     🌟 HASHMATE BOT - Automated Mining       ║
    ║     Automate your Hashmate mining tasks!     ║
    ║  Developed by: https://t.me/sentineldiscus   ║
    ╚══════════════════════════════════════════════╝
  BANNER
  banner.lines.each { |line| log(line.chomp, 'cyan') }

  tokens = %w[MATE TON CATI DOGS STARS NOT PX MAJOR]
  init_data_list = load_init_data
  last_selected_token = nil

  loop do
    init_data_list.each do |init_data|
      username = get_username(init_data)
      log("Processing account #{username}", 'yellow')
      access_token = login(init_data)
      next unless access_token

      puts 'Select token for mining:'
      tokens.each_with_index { |token, i| puts "#{i + 1}. #{token}".bold }
      print "Select token number (1-8) [#{last_selected_token || ''}]: ".cyan.bold
      begin
        choice = STDIN.gets.chomp
        choice = choice.empty? && last_selected_token ? tokens.index(last_selected_token) : choice.to_i - 1
        if (0..tokens.length - 1).include?(choice)
          selected_token = tokens[choice]
          last_selected_token = selected_token
          if select_mining(selected_token, access_token)
            if start_mining(access_token)
              log("Mining #{selected_token} running for #{username}", 'green')
            end
          end
        else
          log('Invalid token selection', 'red')
        end
      rescue StandardError
        log('Invalid input, must be a number 1-8', 'red')
      end

      sleep(5)
    end

    wait_time = rand(6 * 3600..12 * 3600)
    log("Waiting #{wait_time / 3600} hours for reset...", 'yellow')
    display_countdown(wait_time)

    init_data_list.each do |init_data|
      username = get_username(init_data)
      log("Resetting account #{username}", 'yellow')
      access_token = login(init_data)
      reset_mining(access_token) if access_token
    end
  end
end

main if __FILE__ == $PROGRAM_NAME
