class Category < ApplicationRecord
  has_many :documents, dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :name, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }, allow_blank: true

  scope :alphabetical, -> { order(name: :asc) }
  scope :with_documents, -> { where("documents_count > 0") }

  def to_s
    name
  end
end
