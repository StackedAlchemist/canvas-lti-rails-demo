class CourseContent < ApplicationRecord
  has_many :content_versions, dependent: :destroy
  belongs_to :published_version, class_name: "ContentVersion",
                                 foreign_key: :published_version_id,
                                 optional: true

  validates :canvas_course_id, presence: true
  validates :title,            presence: true

  def latest_draft
    content_versions.drafts.order(version_number: :desc).first
  end

  def next_version_number
    (content_versions.maximum(:version_number) || 0) + 1
  end
end
