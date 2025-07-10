class CommentsController < ApplicationController
  # Load parent resource when present
  load_and_authorize_resource :post, if: -> { params[:post_id].present? }
  
  # Load main resource through parent or directly
  load_and_authorize_resource :comment, through: :post, if: -> { params[:post_id].present? }
  load_and_authorize_resource :comment, unless: -> { params[:post_id].present? }

  def create
    @comment.user = current_user
    if @comment.save
      redirect_to @post, notice: 'Comment was successfully created.'
    else
      redirect_to @post, alert: 'Comment could not be created.'
    end
  end

  def update
    if @comment.update(comment_params)
      redirect_to @post, notice: 'Comment was successfully updated.'
    else
      redirect_to @post, alert: 'Comment could not be updated.'
    end
  end

  def destroy
    @comment.destroy
    redirect_to @post, notice: 'Comment was successfully deleted.'
  end

  private

  def comment_params
    params.require(:comment).permit(:content)
  end
end 