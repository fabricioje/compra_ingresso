class SeatsController < ApplicationController
  before_action :set_event, only: %i[index create]
  before_action :set_seat, only: %i[show update destroy reserve release]

  # GET /events/:event_id/seats
  def index
    seats = @event.seats.order(:id)

    if params[:status].present?
      unless Seat.statuses.key?(params[:status])
        return render json: { error: "status inválido: #{params[:status]}" },
                      status: :unprocessable_entity
      end

      seats = seats.where(status: params[:status])
    end

    seats = seats.where(sector: params[:sector]) if params[:sector].present?

    render json: seats.map { |seat| seat_json(seat) }
  end

  # GET /seats/:id
  def show
    render json: seat_json(@seat)
  end

  # POST /events/:event_id/seats
  def create
    seat = @event.seats.new(seat_params)

    if seat.save
      render json: seat_json(seat), status: :created
    else
      render json: { errors: seat.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /seats/:id
  def update
    if @seat.update(seat_params)
      render json: seat_json(@seat)
    else
      render json: { errors: @seat.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /seats/:id
  def destroy
    if @seat.vendido?
      return render json: { errors: { base: [ "Assento vendido não pode ser removido" ] } },
                    status: :unprocessable_entity
    end

    if @seat.destroy
      head :no_content
    else
      render json: { errors: @seat.errors }, status: :unprocessable_entity
    end
  end

  # POST /seats/:id/reserve
  def reserve
    user = User.find(params.require(:user_id))

    if @seat.reserve!(user)
      render json: seat_json(@seat)
    else
      render json: { errors: @seat.errors }, status: :conflict
    end
  end

  # POST /seats/:id/release
  def release
    if @seat.release!
      render json: seat_json(@seat)
    else
      render json: { errors: @seat.errors }, status: :conflict
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_seat
    @seat = Seat.find(params[:id])
  end

  # status, user_id e reserved_until ficam de fora de propósito: o estado do
  # assento só muda por reserve!/release!.
  def seat_params
    params.expect(seat: %i[sector row number price])
  end

  def seat_json(seat)
    seat.as_json(only: %i[id event_id sector row number price status reserved_until user_id created_at updated_at])
        .merge("disponivel" => seat.disponivel?)
  end
end
