module Admin
  class DocumentsController < Admin::BaseController
    include Auditable

    MAX_BULK_FILES = ENV.fetch("MAX_BULK_FILES", "20").to_i
    MAX_FILE_SIZE = Document::MAX_FILE_SIZE_BYTES

    def index
      @documents = Document.includes(:user, :category).order(created_at: :desc)
      @documents = @documents.where(category_id: params[:category_id]) if params[:category_id].present?
      @categories = Category.alphabetical
    end

    def new
      @document = Document.new
      @categories = Category.alphabetical
    end

    def create
      @document = current_user.documents.build(document_params)

      if params[:document][:file].present?
        @document.filename = params[:document][:file].original_filename
        @document.content_type = params[:document][:file].content_type
        @document.file_size = params[:document][:file].size
      end

      if @document.save
        audit_resource(@document)
        redirect_to admin_documents_path, notice: "Document uploaded successfully. Processing will begin shortly."
      else
        @categories = Category.alphabetical
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      @document = Document.find_by!(id: params[:id])
      @document.destroy
      audit_resource(@document)

      respond_to do |format|
        format.html { redirect_to admin_documents_path, notice: "Document deleted successfully." }
        format.turbo_stream
      end
    end

    def bulk_create
      files = params[:files] || []
      category_id = params[:category_id].presence

      return render json: { error: "No files provided" }, status: :unprocessable_entity if files.empty?

      if files.size > MAX_BULK_FILES
        return render json: { error: "Maximum #{MAX_BULK_FILES} files allowed" }, status: :unprocessable_entity
      end

      results = { successful: [], failed: [] }

      files.each do |file|
        if file.size > MAX_FILE_SIZE
          results[:failed] << { filename: file.original_filename,
                                error: "File too large (max #{MAX_FILE_SIZE / 1.megabyte}MB)" }
          next
        end

        document = current_user.documents.build(
          title: if params[:title_prefix].present?
                   "#{params[:title_prefix]} - #{file.original_filename}"
                 else
                   file.original_filename.sub(
                     /\.[^.]+$/, ''
                   )
                 end,
          file: file,
          filename: file.original_filename,
          content_type: file.content_type,
          file_size: file.size,
          category_id: category_id
        )

        if document.save
          results[:successful] << { id: document.id, title: document.title }
        else
          results[:failed] << { filename: file.original_filename, error: document.errors.full_messages.join(", ") }
        end
      end

      audit_resources(Document.where(id: results[:successful].pluck(:id))) if results[:successful].any?

      render json: results
    end

    private

    def document_params
      params.require(:document).permit(:title, :file, :category_id)
    end
  end
end
