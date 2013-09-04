class SessionsController < ApplicationController

  def new
  end

  # POST /sessions
  # POST /sessions.json
  def create
    user = User.find_by_name(params[:session][:name])

    respond_to do |format|
      if user && user.authenticate(params[:session][:password])
        sign_in user

        format.html { redirect_back_or user }
        format.json { render :json => { :success => true }, :status => :ok }
      else
        format.html {
          flash.now[:error] = 'Invalid name/password combination'
          render 'new'
        }
        format.json { render :json => { :success => false }, status: :unauthorized }
      end
    end
  end

  def destroy
    sign_out
    redirect_to root_url
  end
end