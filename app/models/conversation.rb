class Conversation < ApplicationRecord
  belongs_to :user
  has_many :messages, dependent: :destroy

  validates :title, length: { maximum: 255 }

  before_create :set_default_title

  def last_message_at
    messages.maximum(:created_at) || created_at
  end

  private

  def set_default_title
    self.title ||= "New Conversation"
  end
end
