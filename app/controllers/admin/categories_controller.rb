module Admin
  class CategoriesController < BaseController
    include Auditable

    before_action :set_category, only: %i[show edit update destroy]

    def index
      @categories = Category.alphabetical.includes(:documents)
    end

    def show
      @documents = @category.documents.order(created_at: :desc)
    end

    def new
      @category = Category.new
    end

    def edit
    end

    def create
      @category = Category.new(category_params)

      if @category.save
        audit_resource(@category)
        redirect_to admin_categories_path, notice: "Category created successfully"
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @category.update(category_params)
        audit_resource(@category)
        redirect_to admin_categories_path, notice: "Category updated successfully"
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      documents_count = @category.documents.count
      @category.destroy
      audit_resource(@category)

      notice = if documents_count.positive?
                 "Category deleted. #{documents_count} document(s) were unassigned."
               else
                 "Category deleted successfully"
               end
      redirect_to admin_categories_path, notice: notice
    end

    private

    def set_category
      @category = Category.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      AdminAuditLog.log_action(
        user: current_user,
        action: "access_denied",
        change_data: { error: "Category not found", id: params[:id] },
        request: request
      )
      redirect_to admin_categories_path, alert: "Category not found" and return
    end

    def category_params
      params.require(:category).permit(:name, :description)
    end
  end
end
