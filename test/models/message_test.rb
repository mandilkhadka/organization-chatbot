require "test_helper"

class MessageTest < ActiveSupport::TestCase
  # Test role enum
  test "role enum should have correct values" do
    assert_equal 0, Message.roles[:user]
    assert_equal 1, Message.roles[:assistant]
  end

  test "should create user message" do
    message = messages(:user_message)

    assert_predicate message, :user?
    assert_not message.assistant?
  end

  test "should create assistant message" do
    message = messages(:assistant_message)

    assert_predicate message, :assistant?
    assert_not message.user?
  end

  # Test feedback enum
  test "feedback enum should have correct values" do
    assert_equal 0, Message.feedbacks[:none]
    assert_equal 1, Message.feedbacks[:positive]
    assert_equal 2, Message.feedbacks[:negative]
  end

  test "should set positive feedback" do
    message = messages(:assistant_message)
    message.update(feedback: :positive)

    assert_predicate message, :feedback_positive?
  end

  test "should set negative feedback" do
    message = messages(:assistant_message)
    message.update(feedback: :negative)

    assert_predicate message, :feedback_negative?
  end

  # Test status enum
  test "status enum should have correct values" do
    assert_equal 0, Message.statuses[:pending]
    assert_equal 1, Message.statuses[:streaming]
    assert_equal 2, Message.statuses[:complete]
    assert_equal 3, Message.statuses[:failed]
  end

  test "should have pending status" do
    message = messages(:pending_assistant_message)

    assert_predicate message, :status_pending?
  end

  test "should have streaming status" do
    message = messages(:streaming_assistant_message)

    assert_predicate message, :status_streaming?
  end

  test "should have complete status" do
    message = messages(:assistant_message)

    assert_predicate message, :status_complete?
  end

  test "should have failed status" do
    message = messages(:failed_assistant_message)

    assert_predicate message, :status_failed?
  end

  # Test validations
  test "should require role" do
    message = Message.new(
      conversation: conversations(:employee_conversation),
      content: "Test content",
      status: :complete
    )

    assert_not message.save
    assert_includes message.errors[:role], "can't be blank"
  end

  test "should allow empty content for pending assistant messages" do
    message = Message.new(
      conversation: conversations(:employee_conversation),
      role: :assistant,
      status: :pending,
      content: ""
    )

    assert message.save
  end

  test "should allow empty content for streaming assistant messages" do
    message = Message.new(
      conversation: conversations(:employee_conversation),
      role: :assistant,
      status: :streaming,
      content: ""
    )

    assert message.save
  end

  # Test associations
  test "should belong to conversation" do
    message = messages(:user_message)

    assert_respond_to message, :conversation
    assert_instance_of Conversation, message.conversation
  end

  test "should have many message_sources" do
    message = messages(:assistant_message)

    assert_respond_to message, :message_sources
  end

  # Test scopes
  test "ordered scope should order messages by created_at ascending" do
    conversation = conversations(:employee_conversation)
    messages = conversation.messages.ordered

    assert_equal messages.to_a, messages.sort_by(&:created_at)
  end
end
