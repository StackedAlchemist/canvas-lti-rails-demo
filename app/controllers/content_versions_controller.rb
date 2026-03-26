class ContentVersionsController < ApplicationController
  before_action :require_lti_launch
  before_action :require_instructor
  before_action :set_course_content

  def new
    @version = @course_content.content_versions.new
  end

  def create
    @version = @course_content.content_versions.new(version_params)
    @version.status         = "draft"
    @version.author_id      = @lti_launch.canvas_user_id
    @version.author_name    = @lti_launch.raw_jwt_claims.dig(
                                "https://purl.imsglobal.org/spec/lti/claim/lis", "person_name_full"
                              ) || @lti_launch.canvas_user_id
    @version.version_number = @course_content.next_version_number

    if @version.save
      redirect_to course_content_path(@course_content),
                  notice: "Draft saved as version #{@version.version_number}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def publish
    @version = @course_content.content_versions.find(params[:id])
    @version.update!(status: "published")
    @course_content.update!(published_version: @version)

    Rails.logger.info "[Content] Published version #{@version.version_number} of '#{@course_content.title}' by #{@lti_launch.canvas_user_id}"

    redirect_to course_content_path(@course_content),
                notice: "Version #{@version.version_number} is now published."
  end

  def rollback
    source    = @course_content.content_versions.find(params[:id])
    new_draft = @course_content.content_versions.create!(
      body:           source.body,
      author_id:      @lti_launch.canvas_user_id,
      author_name:    @lti_launch.raw_jwt_claims.dig(
                        "https://purl.imsglobal.org/spec/lti/claim/lis", "person_name_full"
                      ) || @lti_launch.canvas_user_id,
      version_number: @course_content.next_version_number,
      status:         "draft",
      change_summary: "Rolled back from version #{source.version_number}"
    )

    Rails.logger.info "[Content] Rollback to v#{source.version_number} → new draft v#{new_draft.version_number} by #{@lti_launch.canvas_user_id}"

    redirect_to course_content_path(@course_content),
                notice: "Rolled back to version #{source.version_number} — saved as draft v#{new_draft.version_number}."
  end

  private

  def set_course_content
    @course_content = CourseContent.find(params[:course_content_id])
  end

  def version_params
    params.require(:content_version).permit(:body, :change_summary)
  end
end
