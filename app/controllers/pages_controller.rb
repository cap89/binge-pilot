class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home, :contentchoice, :moods]

  def home
  end

  def profile
    @user = current_user
    # IN THE VIEW DO:
    # @user.name
    # @user.movies
  end

  def contentchoice
  end

  def moods
    @is_movie = params[:movies] == "true"
  end
end
