require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'phony'


def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('../output') unless Dir.exist?('../output')

  filename = "../output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_number(phone_number)

  begin
    normal_phone_number = Phony.normalize(phone_number)

    #good number
    if normal_phone_number.length == 10
      return normal_phone_number

    #good number
    elsif normal_phone_number == 11 and normal_phone_number[0] == "1"
      return normal_phone_number[1..-1]

    #bad number
    else
      return -1
    end

  rescue StandardError => e
    puts "Phone number error: #{e.message}"
    return -1
  end
end

def time_target(raw_time, hours_count)
  raw_time = raw_time.split(" ")
  raw_time = raw_time[1]
  timestamp = Time.parse(raw_time)
  hour = timestamp.hour

  hours_count[hour] ||= 0 #if the value of this key is not initialized, it is null so it will be initialized with 0
  hours_count[hour] += 1
end

def max_value_hash(my_hash)
  max_value = 0
  max_key = 0

  my_hash.each do |key, value|
    if max_value == 0 || value > max_value
    max_value = value
    max_key = key
    end
  end
  max_key
end

def day_target(raw_time, days_count)
  raw_time = raw_time.split(" ")
  raw_time = raw_time[0]

  timestamp = Date.strptime(raw_time, "%m/%d/%y")

  days_count[timestamp.wday] ||= 0
  days_count[timestamp.wday] += 1
end

puts '### EventManager Initialized ###'


template_letter = File.read('../form_letter.erb')
erb_template = ERB.new template_letter

#Hash to count the hours of day for each register
hours_count = Hash.new
#Hash to put each phone number normalized
phone_number_list = Hash.new
#Hash to count the day of the week with the most registers
days_count = Hash.new

contents = CSV.open(
  '../event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)

  phone_number = clean_phone_number(row[:homephone])
  phone_number_list[id] = phone_number

  time_target(row[:regdate], hours_count)

  day_target(row[:regdate], days_count)
  puts "*"

end

#Print each phone number normalized
# phone_number_list.each do |key, value|
#   puts "key: #{key} value: #{value}"
# end

best_hour = max_value_hash(hours_count)
puts "The hour of the day which people is most registered is #{best_hour}"

best_day = max_value_hash(days_count)

puts "The day which people is most registered is #{Date::DAYNAMES[best_day]}"
puts "\n"
puts "### EventManager Finalized ###"
