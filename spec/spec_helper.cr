require "spec"
require "../src/tele-broadcast"

def flush_namespace(redis, namespace)
  redis.keys("#{namespace}*").each do |key|
    redis.del(key)
  end
end
