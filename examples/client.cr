require "option_parser"

recipients = [] of Int32
text = uninitialized String
photo_path = "/spec/crystal_logo.png"

OptionParser.parse! do |parser|
  parser.banner = "Usage: examples/simple_client [arguments]"
  parser.on("-t TEXT", "--text TEXT", "Text to broadcast") { |t| text = t }
  parser.on("-p PATH", "--photo PATH", "Path to an example image") { |p| photo_path = p }
  parser.on("-r REC", "--recipients REC", "Telegram IDs to send to, divided by comma") { |r| recipients = r.split(",").map &.to_i }
  parser.on("-h", "--help", "Show help") { puts parser; exit }
end

raise ArgumentError.new("Must specify recipients!") unless recipients.any?
raise ArgumentError.new("Must specify text") if text.empty?

require "tele/requests/send_message"
require "tele/requests/send_photo"
require "../src/tele-broadcast/repositories/redis"
require "../src/tele-broadcast/client"

logger = Logger.new(STDOUT).tap(&.level = Logger::DEBUG)
repo = Tele::Broadcast::Repositories::Redis.new(Redis.new, logger, "tele:example_broadcasting:") # Don't forget to add a colon in the end of namespace

client = Tele::Broadcast::Client.new(repo, logger)

requests = [
  Tele::Requests::SendMessage.new(chat_id: 0, text: text),
  Tele::Requests::SendPhoto.new(chat_id: 0, photo: File.open(Dir.current + photo_path)),
]

client.broadcast(requests, recipients)
