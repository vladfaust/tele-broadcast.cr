module Tele::Broadcast
  # :nodoc:
  alias RequestHash = Hash(String, String | File)

  # :nodoc:
  struct Payload
    getter id : Int32
    getter requests : Array(RequestHash)
    getter recipients : Array(Int32)
    getter broadcast_at : Time

    def initialize(@id, @requests, @recipients, @broadcast_at)
    end
  end
end
