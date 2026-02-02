class MessageSource < ApplicationRecord
  belongs_to :message
  belongs_to :document_chunk

  validates :relevance_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true

  delegate :document, to: :document_chunk
end
