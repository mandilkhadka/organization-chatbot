require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:employee_one)
    @other_user = users(:employee_two)
    @conversation = conversations(:employee_conversation)
    @other_conversation = conversations(:other_user_conversation)
    @empty_conversation = conversations(:employee_empty_conversation)
  end

  # Test authentication
  test "should redirect to login when not authenticated" do
    post conversation_messages_path(@conversation), params: {
      message: { content: "Test message" }
    }
    assert_redirected_to new_user_session_path
  end

  # Test creating messages with valid content
  test "should create user message with valid content" do
    sign_in @user

    assert_difference ["Message.count"], 2 do # user + assistant placeholder
      post conversation_messages_path(@conversation), params: {
        message: { content: "What is the vacation policy?" }
      }, as: :turbo_stream
    end

    user_message = @conversation.messages.where(role: :user).last
    assert_equal "What is the vacation policy?", user_message.content
    assert user_message.status_complete?

    assistant_message = @conversation.messages.where(role: :assistant).last
    assert assistant_message.status_pending?
    assert_equal "", assistant_message.content
  end

  test "should queue GenerateResponseJob when creating message" do
    sign_in @user

    assert_enqueued_with(job: GenerateResponseJob) do
      post conversation_messages_path(@conversation), params: {
        message: { content: "Test question" }
      }, as: :turbo_stream
    end
  end

  test "should strip whitespace from message content" do
    sign_in @user

    post conversation_messages_path(@conversation), params: {
      message: { content: "  Test message  " }
    }, as: :turbo_stream

    user_message = @conversation.messages.where(role: :user).last
    assert_equal "Test message", user_message.content
  end

  # Test rejecting blank content
  test "should reject blank content" do
    sign_in @user

    assert_no_difference "Message.count" do
      post conversation_messages_path(@conversation), params: {
        message: { content: "" }
      }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
  end

  test "should reject whitespace-only content" do
    sign_in @user

    assert_no_difference "Message.count" do
      post conversation_messages_path(@conversation), params: {
        message: { content: "   " }
      }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
  end

  # Test conversation title update on first user message
  test "should update conversation title on first user message" do
    sign_in @user

    # Make sure empty conversation has no user messages
    @empty_conversation.messages.destroy_all

    post conversation_messages_path(@empty_conversation), params: {
      message: { content: "What is the employee handbook about?" }
    }, as: :turbo_stream

    @empty_conversation.reload
    assert_equal "What is the employee handbook about?", @empty_conversation.title
  end

  test "should truncate long titles to 50 characters" do
    sign_in @user

    # Make sure empty conversation has no user messages
    @empty_conversation.messages.destroy_all

    long_message = "a" * 100

    post conversation_messages_path(@empty_conversation), params: {
      message: { content: long_message }
    }, as: :turbo_stream

    @empty_conversation.reload
    assert_operator @empty_conversation.title.length, :<=, 50
  end

  # Test authorization - can't access other users' conversations
  test "should not allow creating messages in other user's conversation" do
    sign_in @user

    # Accessing another user's conversation should return 404
    post conversation_messages_path(@other_conversation), params: {
      message: { content: "Unauthorized message" }
    }, as: :turbo_stream

    assert_response :not_found
  end

  test "should allow users to access their own conversations" do
    sign_in @user

    assert_nothing_raised do
      post conversation_messages_path(@conversation), params: {
        message: { content: "My own message" }
      }, as: :turbo_stream
    end

    assert_response :success
  end

  # Test response format
  test "should respond with turbo_stream format" do
    sign_in @user

    post conversation_messages_path(@conversation), params: {
      message: { content: "Test message" }
    }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end
end
