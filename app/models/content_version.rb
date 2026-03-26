class ContentVersion < ApplicationRecord
  belongs_to :course_content

  validates :body,           presence: true
  validates :author_id,      presence: true
  validates :version_number, presence: true,
                             uniqueness: { scope: :course_content_id }
  validates :status, inclusion: { in: %w[draft published] }

  scope :published, -> { where(status: "published") }
  scope :drafts,    -> { where(status: "draft") }
  scope :ordered,   -> { order(version_number: :desc) }

  def published?
    status == "published"
  end

  def draft?
    status == "draft"
  end
end
