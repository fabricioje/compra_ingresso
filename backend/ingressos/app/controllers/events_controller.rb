class EventsController < ApplicationController
  before_action :set_event, only: %i[show update destroy]

  # GET /events
  def index
    render json: Event.order(:id).map { |event| event_json(event) }
  end

  # GET /events/:id
  def show
    render json: event_json(@event)
  end

  # POST /events
  def create
    event = Event.new(event_params)

    if event.save
      render json: event_json(event), status: :created
    else
      render json: { errors: event.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /events/:id
  def update
    if @event.update(event_params)
      render json: event_json(@event)
    else
      render json: { errors: @event.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /events/:id
  def destroy
    @event.destroy
    head :no_content
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.expect(event: %i[name date time local])
  end

  def event_json(event)
    event.as_json(only: %i[id name date time local created_at updated_at])
  end
end
