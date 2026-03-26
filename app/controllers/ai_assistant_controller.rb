class AiAssistantController < ApplicationController
  before_action :require_lti_launch

  # POST /ai/chat
  def chat
    user_message = params[:message].to_s.strip
    return render json: { error: "Message cannot be blank." }, status: :unprocessable_entity if user_message.blank?

    conversation = AiConversation.find_or_create_by!(
      canvas_user_id:   @lti_launch.canvas_user_id,
      canvas_course_id: @lti_launch.course_id
    ) do |c|
      c.lti_launch = @lti_launch
    end

    Rails.logger.info "[AI] Chat request from user #{@lti_launch.canvas_user_id} in course #{@lti_launch.course_id}"

    response_text = AiAssistantService.new(conversation, user_message, @lti_launch).call

    render json: { response: response_text, message_count: conversation.messages.length }
  rescue AiAssistantService::ApiError => e
    Rails.logger.error "[AI] Chat error for #{@lti_launch.canvas_user_id}: #{e.message}"
    render json: { error: "The AI assistant is unavailable. Please try again shortly." },
           status: :service_unavailable
  end

  # GET /ai/analytics
  def analytics
    return render plain: "Instructor access required.", status: :forbidden unless @lti_launch.instructor?

    @conversations       = AiConversation.where(canvas_course_id: @lti_launch.course_id).order(updated_at: :desc)
    @total_conversations = @conversations.count
    @total_messages      = @conversations.sum { |c| c.messages.length }
    @keyword_frequency   = build_keyword_frequency(@conversations)
  end

  private

  def build_keyword_frequency(conversations)
    stop_words = %w[the a an and or but in on at to for of with is are was were be been
                    being have has had do does did will would could should may might shall
                    i me my we our you your he she it its they them their what which who
                    this that these those am is are can how why when where what]

    word_counts = Hash.new(0)
    conversations.each do |conv|
      conv.messages.select { |m| m["role"] == "user" }.each do |m|
        m["content"].to_s.downcase.scan(/\b[a-z]{4,}\b/).each do |word|
          word_counts[word] += 1 unless stop_words.include?(word)
        end
      end
    end

    word_counts.sort_by { |_, count| -count }.first(20).to_h
  end
end
