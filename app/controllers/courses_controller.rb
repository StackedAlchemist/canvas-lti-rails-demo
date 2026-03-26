class CoursesController < ApplicationController
  before_action :require_lti_launch
  before_action :set_course_content

  def show
    @version = @course_content.published_version

    if @version.nil?
      render plain: "No published content yet.", status: :not_found
    end
  end

  private

  def set_course_content
    @course_content = CourseContent.find(params[:id])
  end
end
