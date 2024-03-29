class ArticlesController < ApplicationController
  before_filter :signed_in_user
  before_filter :admin_user, only: [:create, :destroy]

  # GET /articles
  # GET /articles.json
  def index
    params[:count] ||= 3
    params[:since_id]  ||= Article.order(:id).first
    params[:max_id] ||= Article.order(:id).last

    if params[:source_id].nil? then
      @articles = Article.find :all,
                               :conditions => ['id >= ? AND id <= ? AND preview_chunks IS NOT NULL AND preview_chunks != -1', params[:since_id], params[:max_id]],
                               :limit => params[:count],
                               :order => 'id desc'
    else
      @articles = Article.find :all,
                               :conditions => ['id >= ? AND id <= ? AND preview_chunks IS NOT NULL AND preview_chunks != -1 AND source_id = ?', params[:since_id], params[:max_id], params[:source_id]],
                               :limit => params[:count],
                               :order => 'id desc'
    end

    respond_to do |format|
     format.html # index.html.erb
     format.json { render json: @articles.to_json(:include => :chunks) }
    end
  end

  # GET /articles/1
  # GET /articles/1.json
  def show
    Keen.publish("articles", { :article_id => params[:id], :user_id => current_user.id })

    @article = Article.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @article }
    end
  end

  # GET /articles/new
  # GET /articles/new.json
  def new
    @article = Article.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @article }
    end
  end

  # GET /articles/1/edit
  def edit
    @article = Article.find(params[:id])
  end

  # POST /articles
  # POST /articles.json
  def create
    @article = Article.new(user_params)

    respond_to do |format|
      if @article.save
        format.html { redirect_to @article, notice: 'Article was successfully created.' }
        format.json { render json: @article, status: :created, location: @article }
      else
        format.html { render action: "new" }
        format.json { render json: @Article.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /articles/1
  # PUT /articles/1.json
  def update
    @article = Article.find(params[:id])

    respond_to do |format|
      if @article.update_attributes(user_params)
        format.html { redirect_to @article, notice: 'Article was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @Article.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /articles/1
  # DELETE /articles/1.json
  def destroy
    @article = Article.find(params[:id])
    @article.destroy

    respond_to do |format|
      format.html { redirect_to articles_url }
      format.json { head :no_content }
    end
  end

  private

    def user_params
      params.require(:article).permit(:article_url, :author, :body, :image_url, :preview, :preview_chunks, :source_id, :title, :published_at)
    end
end
