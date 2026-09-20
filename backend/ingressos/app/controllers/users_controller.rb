class UsersController < ApplicationController
  before_action :set_user, only: %i[show update destroy]

  # GET /users
  def index
    render json: User.order(:id).map { |user| user_json(user) }
  end

  # GET /users/:id
  def show
    render json: user_json(@user)
  end

  # POST /users
  def create
    user = User.new(user_params)

    if user.save
      render json: user_json(user), status: :created
    else
      render json: { errors: user.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /users/:id
  def update
    if @user.update(user_params)
      render json: user_json(@user)
    else
      render json: { errors: @user.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /users/:id
  def destroy
    @user.destroy
    head :no_content
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.expect(user: %i[name email password password_confirmation])
  end

  def user_json(user)
    user.as_json(only: %i[id name email created_at updated_at])
  end
end
