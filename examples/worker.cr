require "option_parser"

token = uninitialized String

OptionParser.parse! do |parser|
  parser.banner = "Usage: examples/simple_worker [arguments]"
  parser.on("-t TOKEN", "--token TOKEN", "Telegram Bot API token") { |t| token = t }
  parser.on("-h", "--help", "Show help") { puts parser }
end

raise ArgumentError.new("Must specify token") if token.empty?

require "../src/tele-broadcast/repositories/redis"

logger = Logger.new(STDOUT).tap(&.level = Logger::DEBUG)
repo = Tele::Broadcast::Repositories::Redis.new(Redis.new, logger, "tele:example_broadcasting:") # Don't forget to add a colon in the end of namespace

require "../src/tele-broadcast/worker"

worker = Tele::Broadcast::Worker.new(token, repo, logger)
worker.run
