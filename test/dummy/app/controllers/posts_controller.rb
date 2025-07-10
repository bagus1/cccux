class PostsController < ApplicationController
  load_and_authorize_resource
  before_action :authenticate_user!

  def index
    @posts = Post.all
    render plain: "Posts index"
  end

  def show
    render plain: "Post #{@post.id}"
  end

  def new
    @post = Post.new
    render plain: "New post form"
  end

  def create
    @post = current_user.posts.build(post_params)
    if @post.save
      redirect_to @post, notice: 'Post was successfully created.'
    else
      render :new
    end
  end

  def edit
    render plain: "Edit post #{@post.id}"
  end

  def update
    if @post.update(post_params)
      redirect_to @post, notice: 'Post was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @post.destroy
    redirect_to posts_url, notice: 'Post was successfully destroyed.'
  end

  private

  def post_params
    params.require(:post).permit(:title, :content)
  end

  def current_ability
    @current_ability ||= Cccux::Ability.new(current_user)
  end
end
