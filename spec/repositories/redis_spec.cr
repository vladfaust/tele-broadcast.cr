require "../spec_helper"
require "../../src/tele-broadcast/repositories/redis"

require "tele/requests/send_message"
require "tele/requests/send_photo"

class File
  def ==(other : self)
    self.path == other.path
  end
end

struct Time
  def ==(other : self)
    self.epoch_ms == other.epoch_ms
  end
end

namespace = "tele:broadcasting:testing:redis_spec:"

redis = ::Redis.new
flush_namespace(redis, namespace)

logger = Logger.new(STDOUT).tap &.level = Logger::DEBUG

describe Tele::Broadcast::Repositories::Redis do
  repo = Tele::Broadcast::Repositories::Redis.new(redis, logger, namespace)

  {% for a in %w(queued in_progress failed completed cancelled) %}
    describe "managing " + {{a}} do
      it "works" do
        rand1 = rand(1000)
        rand2 = rand(1000)

        repo.add_to_{{a.id}}(rand1)
        repo.add_to_{{a.id}}(rand2)

        repo.remove_from_{{a.id}}(rand1)
        repo.get_{{a.id}}.should eq([rand2])
      end
    end
  {% end %}

  describe "#incr_last_payload_id" do
    it "works" do
      repo.incr_last_payload_id.should eq(1)
      repo.incr_last_payload_id.should eq(2)
    end
  end

  requests = [
    Tele::Requests::SendMessage.new(
      chat_id: 0,
      text: "Hail to Crystal!",
    ).to_h,
    Tele::Requests::SendPhoto.new(
      chat_id: 0,
      photo: File.open(Dir.current + "/spec/crystal_logo.png"),
    ).to_h,
  ] of Hash(String, String | File)
  payload = Tele::Broadcast::Payload.new(1, requests, [42], Time.now)

  describe "#save_payload & #load_payload" do
    it "works" do
      repo.save_payload(payload)
      loaded = repo.load_payload(1)
      loaded.should eq payload
    end
  end

  describe "#broadcasting_time?" do
    context "when time has come" do
      it "returns true" do
        repo.broadcasting_time?(1).should be_true
      end
    end

    context "when time hasn't come yet" do
      payload = Tele::Broadcast::Payload.new(1, requests, [42], Time.now + 12.hours)
      repo.save_payload(payload)

      it "returns false" do
        repo.broadcasting_time?(1).should be_false
      end
    end
  end

  describe "#update_payload_request" do
    it "works" do
      new_request = Tele::Requests::SendPhoto.new(
        chat_id: 0,
        photo: "some_file_id",
      )
      repo.update_payload_request(1, 2, new_request.to_h).should be_truthy
    end
  end

  describe "managing delivered list" do
    it "work" do
      repo.already_delivered?(1, 42).should be_false
      repo.add_recipient_to_delivered_list(1, 42).should be_truthy
      repo.already_delivered?(1, 42).should be_true
      repo.get_delivered_list(1).should contain(42)
      repo.get_delivered_list_size(1).should eq 1
    end
  end

  describe "managing blocked recipients" do
    it "work" do
      repo.recipient_blocked?(42).should be_false
      repo.add_recipient_to_blocked_list(42).should be_truthy
      repo.recipient_blocked?(42).should be_true
      repo.get_blocked_list.should contain(42)
    end

    describe "for a single payload" do
      repo.incr_blocked_count(1).should eq 1
      repo.get_blocked_count(1).should eq 1
    end
  end

  describe "managing deleted accounts" do
    it "work" do
      repo.account_deleted?(42).should be_false
      repo.add_account_to_deleted_list(42).should be_truthy
      repo.account_deleted?(42).should be_true
      repo.get_deleted_accounts_list.should contain(42)
    end

    describe "for a single payload" do
      repo.incr_deleted_count(1).should eq 1
      repo.get_deleted_count(1).should eq 1
    end
  end
end
