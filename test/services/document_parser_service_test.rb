require "test_helper"

class DocumentParserServiceTest < ActiveSupport::TestCase
  setup do
    @parser = DocumentParserService.new
  end

  test "raises UnsupportedFormatError for unknown content type" do
    fake_doc = OpenStruct.new(content_type: "application/zip", file: nil)
    err = assert_raises(DocumentParserService::ParseError) do
      @parser.parse(fake_doc)
    end
    assert_includes err.message, "Unsupported format"
  end

  test "parses a plain text file" do
    txt_blob = OpenStruct.new(download: "Hello world\nLine two")
    fake_doc = OpenStruct.new(content_type: "text/plain", file: txt_blob)

    result = @parser.parse(fake_doc)
    assert_includes result, "Hello world"
    assert_equal Encoding::UTF_8, result.encoding
  end

  test "wraps lower-level parse failures in ParseError" do
    raising_blob = Object.new.tap do |o|
      def o.download; raise "underlying boom"; end
    end
    fake_doc = OpenStruct.new(content_type: "text/plain", file: raising_blob)

    err = assert_raises(DocumentParserService::ParseError) do
      @parser.parse(fake_doc)
    end
    assert_includes err.message, "Failed to parse document"
  end
end
