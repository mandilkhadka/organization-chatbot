require "test_helper"

class GenerateResponseJobTest < ActiveJob::TestCase
  setup do
    @message = messages(:pending_assistant_message)
    @question = "What is the vacation policy?"
  end

  # Test job enqueuing
  test "should enqueue job with correct arguments" do
    assert_enqueued_with(job: GenerateResponseJob, args: [@message.id, @question]) do
      GenerateResponseJob.perform_later(@message.id, @question)
    end
  end

  test "should use default queue" do
    assert_equal "default", GenerateResponseJob.new.queue_name
  end

  # Test job handles nil message gracefully
  test "should handle non-existent message gracefully" do
    non_existent_id = 999999

    # Should not raise an error - returns early
    assert_nothing_raised do
      GenerateResponseJob.perform_now(non_existent_id, @question)
    end
  end

  # Test job skips already completed messages
  test "should not modify already completed messages" do
    completed_message = messages(:assistant_message)
    original_content = completed_message.content
    original_status = completed_message.status

    # The job should return early without modifying the message
    GenerateResponseJob.perform_now(completed_message.id, @question)

    completed_message.reload
    assert_equal original_content, completed_message.content
    assert_equal original_status, completed_message.status
  end

  # Test job skips failed messages
  test "should not modify already failed messages" do
    failed_message = messages(:failed_assistant_message)
    original_content = failed_message.content
    original_status = failed_message.status

    # The job should return early without modifying the message
    GenerateResponseJob.perform_now(failed_message.id, @question)

    failed_message.reload
    assert_equal original_content, failed_message.content
    assert_equal original_status, failed_message.status
  end
end
