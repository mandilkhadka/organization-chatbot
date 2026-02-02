module Admin
  class DocumentsController < Admin::BaseController
    def index
      @documents = Document.includes(:user).order(created_at: :desc)
    end

    def new
      @document = Document.new
    end

    def create
      @document = current_user.documents.build(document_params)

      if params[:document][:file].present?
        @document.filename = params[:document][:file].original_filename
        @document.content_type = params[:document][:file].content_type
        @document.file_size = params[:document][:file].size
      end

      if @document.save
        redirect_to admin_documents_path, notice: "Document uploaded successfully. Processing will begin shortly."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      @document = Document.find(params[:id])
      @document.destroy

      respond_to do |format|
        format.html { redirect_to admin_documents_path, notice: "Document deleted successfully." }
        format.turbo_stream
      end
    end

    private

    def document_params
      params.require(:document).permit(:title, :file)
    end
  end
end
