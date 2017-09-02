require "tele/request"
require "./repository"

module Tele::Broadcast
  class Client
    def initialize(repository @repo : Repository, @logger : Logger); end

    # Queues a broadcasting of *requests* to *recipients*, scheduling it at *when*.
    #
    # ```
    # requests = [Tele::Requests::SendMessage.new(chat_id: 0, text: "Hello")]
    # client.broadcast(requests, recipients: [42, 43], when: Time.now + 3.hours)
    # ```
    def broadcast(requests : Array(Tele::Request), recipients : Array(Int32 | Int64), when broadcast_at : Time = Time.now)
      payload = Payload.new(repo.incr_last_payload_id, requests.map(&.to_h), recipients, broadcast_at)
      repo.save_payload(payload)
      repo.add_to_queued(payload.id)
      logger.info("Added payload #" + payload.id.to_s + " to the broadcasting queue")
      payload.id
    end

    def broadcast(request : Tele::Request, recipients, when broadcast_at = Time.now)
      broadcast([request], recipients, broadcast_at)
    end

    private getter logger, repo
  end
end
