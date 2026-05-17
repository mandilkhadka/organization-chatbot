class DocumentParserService
  class UnsupportedFormatError < StandardError; end
  class ParseError < StandardError; end

  # Hard cap on extracted text to keep one bad upload from OOMing the worker.
  # A 10 MB PDF can easily expand to several MB of plain text.
  MAX_EXTRACTED_BYTES = (ENV.fetch("MAX_EXTRACTED_TEXT_MB", "5").to_i * 1.megabyte).freeze

  def parse(document)
    text = case document.content_type
           when "application/pdf"
             parse_pdf(document.file)
           when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
             parse_docx(document.file)
           when "text/plain"
             parse_txt(document.file)
           else
             raise UnsupportedFormatError, "Unsupported format: #{document.content_type}"
           end

    enforce_text_cap!(text)
  rescue UnsupportedFormatError
    raise
  rescue StandardError => e
    raise ParseError, "Failed to parse document: #{e.message}"
  end

  private

  def enforce_text_cap!(text)
    return text if text.bytesize <= MAX_EXTRACTED_BYTES

    Rails.logger.warn(
      "DocumentParserService: truncating extracted text " \
      "from #{text.bytesize} to #{MAX_EXTRACTED_BYTES} bytes"
    )
    text.byteslice(0, MAX_EXTRACTED_BYTES).force_encoding("UTF-8").scrub("")
  end

  def parse_pdf(file)
    require "pdf-reader"

    text = +""
    file.open do |tempfile|
      reader = PDF::Reader.new(tempfile.path)
      reader.pages.each do |page|
        text << page.text << "\n\n"
        break if text.bytesize > MAX_EXTRACTED_BYTES
      end
    end
    text.strip
  end

  def parse_docx(file)
    require "docx"

    text = +""
    file.open do |tempfile|
      doc = Docx::Document.open(tempfile.path)
      doc.paragraphs.each do |paragraph|
        text << paragraph.text << "\n\n"
        break if text.bytesize > MAX_EXTRACTED_BYTES
      end
    end
    text.strip
  end

  def parse_txt(file)
    file.download.force_encoding("UTF-8")
  end
end
