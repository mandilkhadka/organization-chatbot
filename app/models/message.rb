class Message < ApplicationRecord
  belongs_to :conversation
  has_many :message_sources, dependent: :destroy
  has_many :source_chunks, through: :message_sources, source: :document_chunk

  enum role: { user: 0, assistant: 1 }
  enum feedback: { none: 0, positive: 1, negative: 2 }, _prefix: :feedback

  validates :role, presence: true
  validates :content, presence: true

  scope :ordered, -> { order(created_at: :asc) }
end
