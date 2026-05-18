class Document < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true, counter_cache: true
  has_many :document_chunks, dependent: :destroy
  has_one_attached :file

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  validates :title, presence: true
  validates :filename, presence: true
  validates :file, presence: true, on: :create

  SUPPORTED_CONTENT_TYPES = [
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "text/plain"
  ].freeze

  # Configurable via ENV (defaults to 10 MB).
  MAX_FILE_SIZE_BYTES = (ENV.fetch("MAX_UPLOAD_SIZE_MB", "10").to_i * 1.megabyte).freeze

  validate :acceptable_file_type, on: :create
  validate :acceptable_file_size, on: :create
  validate :non_empty_file, on: :create

  after_create_commit :process_document

  private

  def acceptable_file_type
    return unless file.attached?

    # SECURITY: Don't trust the uploader-supplied content_type. ActiveStorage's
    # blob unfurl already calls Marcel::MimeType.for on the upload IO, so
    # file.blob.content_type is the magic-byte-sniffed type — not the upload
    # header. We just have to verify it's in our allow-list.
    sniffed_type = file.blob&.content_type.to_s

    if sniffed_type.blank? || SUPPORTED_CONTENT_TYPES.exclude?(sniffed_type)
      errors.add(:file, "must be a PDF, DOCX, or TXT file (detected: #{sniffed_type.presence || 'unknown'})")
      return
    end

    # Normalize stored content_type to the sniffed value.
    self.content_type = sniffed_type
  end

  def acceptable_file_size
    return unless file.attached?

    return unless file.byte_size > MAX_FILE_SIZE_BYTES

    errors.add(:file, "is too large (maximum is #{MAX_FILE_SIZE_BYTES / 1.megabyte} MB)")
  end

  def non_empty_file
    return unless file.attached?

    return unless file.byte_size.to_i.zero?

    errors.add(:file, "is empty")
  end

  def process_document
    DocumentProcessorJob.perform_later(id)
  end
end
