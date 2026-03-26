class CourseContentsController < ApplicationController
  before_action :require_lti_launch
  before_action :require_instructor, only: %i[new create]
  before_action :set_course_content, only: %i[show]

  def index
    @course_contents = CourseContent.where(canvas_course_id: @lti_launch.course_id)
                                    .order(created_at: :desc)
  end

  def show
    if @lti_launch.instructor?
      @published_version = @course_content.published_version
      @current_draft     = @course_content.latest_draft
      @all_versions      = @course_content.content_versions.ordered
    else
      @version = @course_content.published_version
      render :show_student and return if @version
      render plain: "No published content yet.", status: :not_found
    end
  end

  def new
    @course_content = CourseContent.new(canvas_course_id: @lti_launch.course_id)
  end

  def create
    @course_content = CourseContent.new(course_content_params)
    @course_content.canvas_course_id = @lti_launch.course_id

    if @course_content.save
      redirect_to course_contents_path, notice: "Content created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_course_content
    @course_content = CourseContent.find(params[:id])
  end

  def course_content_params
    params.require(:course_content).permit(:title)
  end
end
