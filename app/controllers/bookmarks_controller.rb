require_relative "../services/fetch_data_service.rb"
require_relative "../services/fetch_providers.rb"

class BookmarksController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index]
  before_action :set_content_format_and_mood, only: :index
  before_action :fetch_genres_by_mood, only: :index
  before_action :trigger_fetch_service, only: :index
#  before_action :fetch_streaming_links, only: :checkout



def index
  # Example API call, adjust based on your actual implementation
  service = FetchDataService.new(params[:content], params[:mood])
  response = service.call

  if response.present? && response.any?
    @random_result = response.first
    # Assuming @random_result is a hash with expected keys; adjust as needed
    @random_result_title = @random_result["original_title"] || @random_result["original_name"] || "Title not available"
    @random_result_name = @random_result["title"] || @random_result["name"] || "Name not available"
    @random_result_id = @random_result["id"] # Make sure this exists for routing to work
    # Extract other required data similarly
  else
    redirect_to fallback_path, alert: "Data not available for the selected content and mood." and return
  end
end

  def create_bookmark
    content = Content.find_or_create_by(content_identifier: params[:result_id].to_i) do |c|
      c.name = params[:result_title]
      c.picture_url = params[:result_picture]
      c.medium = params[:content]
    end
    Bookmark.create(
      content:,
      user: current_user,
      offered: true,
      status_like: params[:liked] == 'true' ? 'liked' : 'disliked',
      status_watch: params[:watched] == 'true' ? 'watched' : 'not_watched'
    )
    p params
    redirect_to bookmarks_path(mood: params[:mood], content: params[:content]), notice: "Bookmark was created 🎉"
  end

  def change_status_like
    bookmark = Bookmark.find(params[:id])
    if bookmark.status_like == "liked"
      bookmark.status_like = "disliked"
    else
      bookmark.status_like = "liked"
    end
    bookmark.save

    if request.referer&.end_with?(profile_liked_list_path)
      redirect_to profile_liked_list_path
    else
      redirect_to profile_discarded_list_path
    end
  end

  def create_watched_bookmark
    content = Content.find_or_create_by(content_identifier: params[:result_id].to_i) do |c|
      c.name = params[:result_title]
      c.picture_url = params[:result_picture]
    end

    Bookmark.create!(
      content:,
      user_id: params[:user].to_i,
      offered: true,
      status_watch: 'true'
    )
  end

  def checkout
    @content = params[:content] || bookmark.content.medium
    @id = params[:id] || bookmark.content.content_identifier
    @name = params[:name] || params[:result_title]
    @random_result_name_parse = @name.gsub(" ", "-").gsub("'", "-")
  end

  private

  def set_content_format_and_mood
    @content_format = params[:content]
    @mood_name = params[:mood]&.downcase
  end

  def trigger_fetch_service
    fetched_instance = FetchDataService.new(@content_format, @mood_name, @genres_by_mood)
    @all_content_results = fetched_instance.call
    @new_offers = reject_offered_content(@all_content_results)
    @random_result = @new_offers&.sample
      puts "@all_content_results: #{@all_content_results}"
      puts "@new_offers: #{@new_offers}"
      puts "@random_result: #{@random_result}"
  end

  def reject_offered_content(all_content_results)
    offered_content_ids = current_user.bookmarks&.where(offered: true).pluck(:content_id)
    all_content_results&.reject { |result| offered_content_ids.include?(result["id"].to_s) }
  end

  def fetch_genres_by_mood
    if @mood_name.present?
      mood = Mood.find_by('LOWER(name) = ?', @mood_name.downcase)
      if mood
        @genres_by_mood = mood.genres.where(genre_format: @content_format)
      else
        @genres_by_mood = [Genre.where(genre_format: @content_format).sample]
      end
    else
      @genres_by_mood = [Genre.where(genre_format: @content_format).sample]
    end
  end

  def fetch_streaming_links
    fetched_providers = FetchMovieProviderService.new(@content, @id, @name, @random_result_name_parse)
    # @all_streaming_providers = fetched_providers.fetch_movie_urls
  end

end
