class Document < ApplicationRecord
  belongs_to :user
  has_many :document_chunks, dependent: :destroy
  has_one_attached :file

  enum status: { pending: 0, processing: 1, ready: 2, failed: 3 }

  validates :title, presence: true
  validates :filename, presence: true
  validates :file, presence: true, on: :create

  SUPPORTED_CONTENT_TYPES = [
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "text/plain"
  ].freeze

  validate :acceptable_file_type, on: :create

  after_create_commit :process_document

  private

  def acceptable_file_type
    return unless file.attached?

    return if SUPPORTED_CONTENT_TYPES.include?(file.content_type)

    errors.add(:file, "must be a PDF, DOCX, or TXT file")
  end

  def process_document
    DocumentProcessorJob.perform_later(id)
  end
end
