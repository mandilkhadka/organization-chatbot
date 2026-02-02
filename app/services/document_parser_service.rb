class DocumentParserService
  class UnsupportedFormatError < StandardError; end
  class ParseError < StandardError; end

  def parse(document)
    case document.content_type
    when "application/pdf"
      parse_pdf(document.file)
    when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      parse_docx(document.file)
    when "text/plain"
      parse_txt(document.file)
    else
      raise UnsupportedFormatError, "Unsupported format: #{document.content_type}"
    end
  rescue StandardError => e
    raise ParseError, "Failed to parse document: #{e.message}"
  end

  private

  def parse_pdf(file)
    require "pdf-reader"

    text = ""
    file.open do |tempfile|
      reader = PDF::Reader.new(tempfile.path)
      reader.pages.each do |page|
        text << page.text << "\n\n"
      end
    end
    text.strip
  end

  def parse_docx(file)
    require "docx"

    text = ""
    file.open do |tempfile|
      doc = Docx::Document.open(tempfile.path)
      doc.paragraphs.each do |paragraph|
        text << paragraph.text << "\n\n"
      end
    end
    text.strip
  end

  def parse_txt(file)
    file.download.force_encoding("UTF-8")
  end
end
