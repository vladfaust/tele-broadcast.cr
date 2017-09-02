require "tele/client"
require "tele/types/message"
require "./repository"

module Tele::Broadcast
  class Worker
    private getter repo, logger, tele_client

    # How much to sleep in seconds when Telegram returns 5** error
    SERVER_ERROR_SLEEP = 10

    # New broadcasts checking frequency in seconds
    CHECK_PERIOD = 0.5

    MAX_REQUESTS_PER_SECOND = 40

    def initialize(bot_api_token token : String,
                   repository @repo : Repository,
                   @logger : Logger)
      @tele_client = Tele::Client.new(token, @logger)
    end

    def run
      logger.info("Tele::Broadcast::Worker worker is running!")
      loop do
        repo.get_queued.each do |payload_id|
          next unless repo.broadcasting_time?(payload_id)

          repo.remove_from_queued(payload_id)
          repo.add_to_in_progress(payload_id)
          payload = repo.load_payload(payload_id)

          logger.info("Started broadcasting payload #" + payload_id.to_s + " to " + payload.recipients.size.to_s + " recipients...")
          broadcasting_started_at = Time.now

          begin
            payload.recipients.each do |chat_id|
              if repo.already_delivered?(payload_id, chat_id)
                logger.debug("Already delivered to " + chat_id.to_s + ", skipping")
                next
              end

              if repo.recipient_blocked?(chat_id)
                logger.debug("Recipient " + chat_id.to_s + " has blocked the bot, skipping")
                next
              end

              if repo.account_deleted?(chat_id)
                logger.debug("Account " + chat_id.to_s + " deleted, skipping")
                next
              end

              begin
                payload.requests.each_with_index do |request, i|
                  random_request_id = rand(1000).to_s

                  logger.debug("Sending request #" + random_request_id + " to " + chat_id.to_s + "...")

                  request["chat_id"] = chat_id.to_s
                  request_started_at = Time.now
                  response = tele_client.request(request["method"].as(String), request, Tele::Types::Message, raise: true).as(Tele::Types::Message)

                  repo.update_payload_request(payload_id, i + 1, request) if replace_file_with_file_id?(request, response)

                  logger.debug("Delivered request #" + random_request_id + " in " + format_time(Time.now - request_started_at))
                end

                repo.add_recipient_to_delivered_list(payload_id, chat_id)
              rescue ex : Tele::Client::LimitExceededError
                logger.warn("Limit exceeded! Will wait for #{ex.delay} seconds")
                sleep ex.delay
              rescue ex : Tele::Client::BlockedByUserError
                logger.warn("User has blocked the bot! Adding #{chat_id} to blocked list")
                repo.add_recipient_to_blocked_list(chat_id)
              rescue ex : Tele::Client::ChatNotFoundError
                logger.warn("Chat #{chat_id} not found, adding to deleted account lists")
                repo.add_account_to_deleted_list(chat_id)
              rescue ex : Tele::Client::ServerError
                logger.warn("Telegram server error (#{ex.message})! Sleeping for #{SERVER_ERROR_SLEEP}")
                sleep SERVER_ERROR_SLEEP
              end
            end

            repo.remove_from_in_progress(payload_id)
            repo.add_to_completed(payload_id)

            logger.info("Done broadcasting payload #" + payload_id.to_s + " in " + format_time(Time.now - broadcasting_started_at) + "!")
            #
          rescue ex
            logger.error("Unhandled error #{ex.class} for payload ##{payload_id}! Message: #{ex.message}")
            repo.remove_from_in_progress(payload_id)
            repo.add_to_failed(payload_id)
          end
        end

        sleep CHECK_PERIOD
      end
    end

    private def replace_file_with_file_id?(request : RequestHash, response : Tele::Types::Message)
      replaced? = false
      {% begin %}
        replaced? = case request.find { |k, v| v.is_a?(File) }.try &.[0]
        {% for field in %w(audio document video voice video_note) %}
          when {{field}}
            request[{{field}}] = response.{{field.id}}.not_nil!.file_id
        {% end %}
        when "photo"
          request["photo"] = response.photo.not_nil!.last.file_id
        end
      {% end %}
      logger.debug("Replaced File with file_id") if replaced?
      replaced?
    end

    private def file_type_to_method(f)
      "send" + f.split("_").map(&.capitalize).join
    end

    private def format_time(time)
      "%{sec}s" % {sec: (time.to_f).round(2)}
    end
  end
end
