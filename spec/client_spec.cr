require "./spec_helper"
require "../src/tele-broadcast/repositories/redis"
require "../src/tele-broadcast/client"

require "tele/requests/send_message"
require "tele/requests/send_photo"

namespace = "tele:broadcasting:testing:client_spec:"

logger = Logger.new(STDOUT).tap(&.level = Logger::FATAL)
redis = Redis.new
flush_namespace(redis, namespace)

repo = Tele::Broadcast::Repositories::Redis.new(Redis.new, logger, namespace)

describe Tele::Broadcast::Client do
  client = Tele::Broadcast::Client.new(repo, logger)

  describe "#broadcast" do
    request = Tele::Requests::SendMessage.new(chat_id: 0, text: "Test")

    context "with single request" do
      it "works" do
        client.broadcast(request, [42])
      end
    end

    context "with multiple requests" do
      requests = [
        request,
        Tele::Requests::SendPhoto.new(chat_id: 0, photo: File.open("./spec/crystal_logo.png")),
      ]

      it "works" do
        client.broadcast(requests, [42])
      end
    end
  end
end
