require "redis"
require "../repository"

module Tele::Broadcast
  class Repositories::Redis < Repository
    private getter redis : ::Redis
    private getter namespace : String
    private getter logger : Logger

    DEFAULT_NAMESPACE = "tele:broadcasting:"

    private KEYS_LISTS             = %w(queued in_progress failed completed cancelled)
    private KEY_BLOCKED_RECIPIENTS = "blocked_recipients"
    private KEY_DELETED_ACCOUNTS   = "deleted_accounts"
    private KEY_LAST_PAYLOAD_ID    = "last_payload_id"
    private KEY_PAYLOADS           = "payloads"
    private KEY_BROADCAST_AT       = "broadcast_at"
    private KEY_RECIPIENT_IDS      = "recipient_ids"
    private KEY_DELIVERED_TO       = "delivered_to"
    private KEY_REQUESTS_COUNT     = "requests_count"
    private KEY_REQUESTS           = "requests"

    def initialize(@redis, @logger, @namespace = DEFAULT_NAMESPACE); end

    {% for a in KEYS_LISTS %}
      def get_{{a.id}}
        redis.smembers(namespace + {{a}}).map &.to_s.to_i32
      end

      def add_to_{{a.id}}(payload_id : Int32)
        redis.sadd(namespace + {{a}}, payload_id)
      end

      def remove_from_{{a.id}}(payload_id : Int32)
        redis.srem(namespace + {{a}}, payload_id)
      end
    {% end %}

    def incr_last_payload_id
      redis.incr(namespace + KEY_LAST_PAYLOAD_ID).to_i32
    end

    def save_payload(payload : Payload)
      prepend = namespace + KEY_PAYLOADS + ":" + payload.id.to_s + ":"

      redis.set(prepend + KEY_BROADCAST_AT, payload.broadcast_at.to_utc.epoch_ms)
      redis.sadd(prepend + KEY_RECIPIENT_IDS, payload.recipients)
      redis.set(prepend + KEY_REQUESTS_COUNT, payload.requests.size)
      payload.requests.map(&.dup).each_with_index do |request, i|
        request.each do |key, value|
          request[key] = value.as(File).path if value.is_a?(IO::FileDescriptor)
        end
        redis.hmset(prepend + KEY_REQUESTS + ":" + (i + 1).to_s, request)
      end
    end

    def load_payload(id : Int32)
      prepend = namespace + KEY_PAYLOADS + ":" + id.to_s + ":"
      Payload.new(
        id: id,
        broadcast_at: Time.epoch_ms(redis.get(prepend + KEY_BROADCAST_AT).not_nil!.to_i64),
        recipients: redis.smembers(prepend + KEY_RECIPIENT_IDS).map &.to_s.to_i,
        requests: redis.get(prepend + KEY_REQUESTS_COUNT).not_nil!.to_i.times.map do |request_id|
          RequestHash.new.tap do |file_hash|
            array = redis.hgetall(prepend + KEY_REQUESTS + ":" + (request_id + 1).to_s)
            hash_from_redis_array(array).each do |k, v|
              file_hash[k] = File.file?(v) ? File.open(v) : v
            end
          end
        end.to_a
      )
    end

    def broadcasting_time?(payload_id : Int32)
      Time.now >= Time.epoch_ms(redis.get(namespace + KEY_PAYLOADS + ":" + payload_id.to_s + ":" + KEY_BROADCAST_AT).not_nil!.to_i64)
    end

    def update_payload_request(payload_id : Int32, request_id : Int32, request : RequestHash)
      redis.hmset(namespace + KEY_PAYLOADS + ":" + payload_id.to_s + ":" + KEY_REQUESTS + ":" + request_id.to_s, request)
    end

    private def delivered_list_key(payload_id : Int32)
      namespace + KEY_PAYLOADS + ":" + payload_id.to_s + ":" + KEY_DELIVERED_TO
    end

    def add_recipient_to_delivered_list(payload_id : Int32, chat_id : Int32)
      redis.sadd(delivered_list_key(payload_id), chat_id)
    end

    def already_delivered?(payload_id : Int32, chat_id : Int32)
      get_delivered_list(payload_id).includes?(chat_id)
    end

    def get_delivered_list(payload_id : Int32)
      redis.smembers(delivered_list_key(payload_id)).map &.to_s.to_i
    end

    private def blocked_list_key
      namespace + KEY_BLOCKED_RECIPIENTS
    end

    def add_recipient_to_blocked_list(chat_id : Int32)
      redis.sadd(blocked_list_key, chat_id)
    end

    def recipient_blocked?(chat_id : Int32)
      get_blocked_list.includes?(chat_id)
    end

    def get_blocked_list : Array(Int32)
      redis.smembers(blocked_list_key).map &.to_s.to_i
    end

    private def deleted_list_key
      namespace + KEY_DELETED_ACCOUNTS
    end

    def add_account_to_deleted_list(chat_id : Int32)
      redis.sadd(deleted_list_key, chat_id)
    end

    def account_deleted?(chat_id : Int32)
      get_deleted_accounts_list.includes?(chat_id)
    end

    def get_deleted_accounts_list
      redis.smembers(deleted_list_key).map &.to_s.to_i
    end

    private def hash_from_redis_array(array : Array(::Redis::RedisValue)) : Hash(String, String)
      keys = [] of String
      values = [] of String
      array.each_with_index { |e, i| i % 2 == 0 ? keys << e.to_s : values << e.to_s }
      Hash(String, String).zip(keys, values)
    end
  end
end
