require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get posts_index_url
    assert_response :success
  end

  test "should get show" do
    # Create a post first, then test showing it
    post = Post.create!(title: "Test Post", content: "Test content", user: User.first || User.create!(email: "test@example.com", password: "password123"))
    get posts_show_url(post)
    assert_response :success
  end

  test "should get new" do
    get posts_new_url
    assert_response :success
  end

  test "should get create" do
    # Test creating a new post
    assert_difference('Post.count') do
      post posts_create_url, params: { post: { title: "New Post", content: "New content", user_id: (User.first || User.create!(email: "test@example.com", password: "password123")).id } }
    end
    assert_redirected_to posts_show_url(Post.last)
  end

  test "should get edit" do
    # Create a post first, then test editing it
    post = Post.create!(title: "Test Post", content: "Test content", user: User.first || User.create!(email: "test@example.com", password: "password123"))
    get posts_edit_url(post)
    assert_response :success
  end

  test "should get update" do
    # Create a post first, then test updating it
    post = Post.create!(title: "Test Post", content: "Test content", user: User.first || User.create!(email: "test@example.com", password: "password123"))
    patch posts_update_url(post), params: { post: { title: "Updated Post", content: "Updated content" } }
    assert_redirected_to posts_show_url(post)
    assert_equal "Updated Post", post.reload.title
  end

  test "should get destroy" do
    # Create a post first, then test destroying it
    post = Post.create!(title: "Test Post", content: "Test content", user: User.first || User.create!(email: "test@example.com", password: "password123"))
    assert_difference('Post.count', -1) do
      delete posts_destroy_url(post)
    end
    assert_redirected_to posts_index_url
  end
end
