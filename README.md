# Tele::Broadcast [![Build Status](https://travis-ci.org/vladfaust/tele-broadcast.cr.svg?branch=master)](https://travis-ci.org/vladfaust/tele-broadcast.cr) [![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://vladfaust.com/tele-broadcast.cr) [![GitHub release](https://img.shields.io/github/release/vladfaust/tele-broadcast.cr.svg)](https://github.com/vladfaust/tele-broadcast.cr/releases)

A broadcasting module for [Tele.cr](https://github.com/vladfaust/tele.cr).

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  tele-broadcast:
    github: vladfaust/tele-broadcast.cr
    version: 0.1.2
```

## Usage

Read some [docs](https://vladfaust.com/tele-broadcast.cr) when you need.

`Tele::Broadcast` is **agnostic** of ORM structure, you just pass a list of `Tele::Request`s and an list of recipients chat IDs and run the Woker. You can either create a custom CLI for broadcasting from the local machine or develop a web-interface.

### Client

The client allows to schedule broadcasts:

```crystal
require "tele/requests/send_message"
require "tele-broadcast/client"
require "tele-broadcast/repositories/redis"

logger = Logger.new(STDOUT).tap(&.level = Logger::DEBUG)
repo = Tele::Broadcast::Repositories::Redis.new(Redis.new, logger, "example_bot:broadcast:") # Don't forget to add a colon in the end of namespace

client = Tele::Broadcast::Client.new(repo, logger)

request = Tele::Requests::SendMessage.new(chat_id: 0, text: "Hello from Tele::Broadcast!")
recipients = [116543174, 155633478] of Int32 # A list of Telegram IDs

client.broadcast(requests, recipients)

# => INFO -- : Added payload #1 to the broadcasting queue
```

Check out `examples/client.cr` and try it yourself:

```shell
crystal /examples/client.cr -- --text="Hola!" -r <Your Telegram ID>
```

Please not that you have to contact the bot at least once so it can send you messages.

### Worker

The worker periodically checks for new broadcasts and handles them:

```crystal
require "tele-broadcast/worker"
require "tele-broadcast/repositories/redis"

logger = Logger.new(STDOUT).tap(&.level = Logger::DEBUG)
repo = Tele::Broadcast::Repositories::Redis.new(Redis.new, logger, "example_bot:broadcast:") # Don't forget to add a colon in the end of namespace

worker = Tele::Broadcast::Worker.new("BOT_API_TOKEN", repo, logger)
worker.run

# =>  INFO -- : Tele::Broadcast::Worker worker is running!
# =>  INFO -- : Started broadcasting payload #1 to 2 recipients...
# => DEBUG -- : Recipient 116543174 has blocked the bot, skipping
# => DEBUG -- : Sending request #727 to 155633478...
# => DEBUG -- : Delivered request #727 in 0.29s
# =>  INFO -- : Done broadcasting payload #1 in 0.29s!
```

Try it yourself:

```shell
crystal /examples/worker.cr -- -t <BOT_API_TOKEN>
```

## Development

There are tests! So please run `crystal spec` while developing.

## Contributing

1. Fork it ( https://github.com/vladfaust/tele-broadcast.cr/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [@vladfaust](https://github.com/vladfaust) Vlad Faust - creator, maintainer
