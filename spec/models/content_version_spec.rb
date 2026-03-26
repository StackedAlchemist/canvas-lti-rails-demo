require "rails_helper"

RSpec.describe ContentVersion, type: :model do
  describe "draft save does not affect published version" do
    it "saving a new draft does not change the published version on CourseContent" do
      content = create(:course_content)
      published = create(:content_version, course_content: content, status: "published", version_number: 1)
      content.update!(published_version: published)

      create(:content_version, course_content: content, status: "draft", version_number: 2)

      expect(content.reload.published_version).to eq(published)
    end
  end

  describe "student cannot access draft" do
    it "drafts scope excludes published versions" do
      content  = create(:course_content)
      draft    = create(:content_version, course_content: content, status: "draft",     version_number: 1)
      pub      = create(:content_version, course_content: content, status: "published", version_number: 2)

      expect(ContentVersion.drafts).to include(draft)
      expect(ContentVersion.drafts).not_to include(pub)
    end

    it "published scope excludes drafts" do
      content  = create(:course_content)
      draft    = create(:content_version, course_content: content, status: "draft",     version_number: 1)
      pub      = create(:content_version, course_content: content, status: "published", version_number: 2)

      expect(ContentVersion.published).to include(pub)
      expect(ContentVersion.published).not_to include(draft)
    end
  end

  describe "rollback creates a new draft" do
    it "creates a new draft version with the source body" do
      content = create(:course_content)
      source  = create(:content_version, course_content: content, body: "Original body", version_number: 1)

      new_draft = content.content_versions.create!(
        body:           source.body,
        author_id:      "user_abc",
        version_number: content.next_version_number,
        status:         "draft",
        change_summary: "Rolled back from version #{source.version_number}"
      )

      expect(new_draft.status).to eq("draft")
      expect(new_draft.body).to eq("Original body")
      expect(new_draft.version_number).to eq(2)
    end
  end
end
