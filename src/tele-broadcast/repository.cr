require "logger"
require "./payload"

module Tele::Broadcast
  # Abstract Repository; a broadcaster can store data anywhere
  abstract class Repository
    abstract def get_queued : Array(Int32)
    abstract def get_in_progress : Array(Int32)
    abstract def get_failed : Array(Int32)
    abstract def get_completed : Array(Int32)
    abstract def get_cancelled : Array(Int32)

    abstract def add_to_queued(payload_id : Int32)
    abstract def add_to_in_progress(payload_id : Int32)
    abstract def add_to_failed(payload_id : Int32)
    abstract def add_to_completed(payload_id : Int32)
    abstract def add_to_cancelled(payload_id : Int32)

    abstract def remove_from_queued(payload_id : Int32)
    abstract def remove_from_in_progress(payload_id : Int32)
    abstract def remove_from_failed(payload_id : Int32)
    abstract def remove_from_completed(payload_id : Int32)
    abstract def remove_from_cancelled(payload_id : Int32)

    # Return the last Payload ID **after increment** (so minimum possible value is *1*)
    abstract def incr_last_payload_id : Int32
    abstract def save_payload(payload : Payload)
    abstract def load_payload(id : Int32) : Payload
    # Has a Payload broadcasting time come?
    abstract def broadcasting_time?(payload_id : Int32) : Bool
    # Update a Payload request. Use to re-assign file fields (photo, video etc.) with their file_id
    abstract def update_payload_request(payload_id : Int32, request_id : Int32, request : RequestHash)

    abstract def add_recipient_to_delivered_list(payload_id : Int32, chat_id : Int32)
    abstract def already_delivered?(payload_id : Int32, chat_id : Int32) : Bool
    abstract def get_delivered_list(payload_id : Int32) : Array(Int32)
    abstract def get_delivered_list_size(payload_id : Int32) : Int32

    abstract def add_recipient_to_blocked_list(chat_id : Int32)
    abstract def recipient_blocked?(chat_id : Int32) : Bool
    abstract def get_blocked_list : Array(Int32)
    abstract def incr_blocked_count(payload_id : Int32)

    abstract def add_account_to_deleted_list(chat_id : Int32)
    abstract def account_deleted?(chat_id : Int32) : Bool
    abstract def get_deleted_accounts_list : Array(Int32)
    abstract def incr_deleted_count(payload_id : Int32)
  end
end
