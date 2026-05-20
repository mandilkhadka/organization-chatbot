class Message < ApplicationRecord
  belongs_to :conversation, touch: true
  has_many :message_sources, dependent: :destroy
  has_many :source_chunks, through: :message_sources, source: :document_chunk

  enum :role, { user: 0, assistant: 1 }
  enum :feedback, { none: 0, positive: 1, negative: 2 }, prefix: :feedback
  enum :status, { pending: 0, streaming: 1, complete: 2, failed: 3 }, prefix: :status

  validates :role, presence: true
  validates :content, presence: true, unless: :assistant_streaming?
  validates :content, length: { maximum: 10_000 }, if: :user?

  scope :ordered, -> { order(created_at: :asc) }

  def streaming?
    status_pending? || status_streaming?
  end

  private

  def assistant_streaming?
    assistant? && (status_pending? || status_streaming?)
  end
end
