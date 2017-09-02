require "./spec_helper"
require "../src/tele-broadcast/repositories/redis"
require "../src/tele-broadcast/worker"

namespace = "tele:broadcasting:testing:worker_spec:"

logger = Logger.new(STDOUT).tap(&.level = Logger::FATAL)
redis = Redis.new
flush_namespace(redis, namespace)

repo = Tele::Broadcast::Repositories::Redis.new(redis, logger, namespace)

describe Tele::Broadcast::Worker do
  worker = Tele::Broadcast::Worker.new("token", repo, logger)

  it "runs" do
    # TODO: Find a way to literally test broadcasting
    spawn do
      worker.run
    end

    sleep 0.0001.seconds
  end
end
