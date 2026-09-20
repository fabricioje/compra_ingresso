require "test_helper"

class SeatsControllerTest < ActionDispatch::IntegrationTest
  test "index lista os assentos do evento" do
    get event_seats_url(events(:one))

    assert_response :success
    assert_equal events(:one).seats.count, JSON.parse(response.body).size
  end

  test "index expõe o campo disponivel" do
    get event_seats_url(events(:one))

    corpo = JSON.parse(response.body).find { |seat| seat["id"] == seats(:expirado).id }

    assert corpo["disponivel"]
  end

  test "index filtra por status" do
    get event_seats_url(events(:one)), params: { status: "livre" }

    assert_response :success
    assert_equal [ seats(:livre).id ], JSON.parse(response.body).map { |seat| seat["id"] }
  end

  test "index filtra por setor" do
    get event_seats_url(events(:one)), params: { sector: "B" }

    assert_equal [ seats(:expirado).id ], JSON.parse(response.body).map { |seat| seat["id"] }
  end

  test "index recusa status desconhecido" do
    get event_seats_url(events(:one)), params: { status: "banana" }

    assert_response :unprocessable_entity
    assert_equal "status inválido: banana", JSON.parse(response.body)["error"]
  end

  test "index de evento inexistente responde 404" do
    get event_seats_url(event_id: 999_999)

    assert_response :not_found
  end

  test "create cria assento no evento" do
    assert_difference "Seat.count", 1 do
      post event_seats_url(events(:one)),
           params: { seat: { sector: "C", row: "2", number: "10", price: 80.0 } },
           as: :json
    end

    assert_response :created
    corpo = JSON.parse(response.body)

    assert_equal "livre", corpo["status"]
    assert_equal events(:one).id, corpo["event_id"]
  end

  test "create sem número responde 422" do
    post event_seats_url(events(:one)), params: { seat: { sector: "C", row: "2" } }, as: :json

    assert_response :unprocessable_entity
  end

  test "create ignora status e user_id enviados pelo cliente" do
    post event_seats_url(events(:one)),
         params: { seat: { sector: "C", row: "3", number: "11", status: "vendido", user_id: users(:one).id } },
         as: :json

    assert_response :created
    corpo = JSON.parse(response.body)

    assert_equal "livre", corpo["status"]
    assert_nil corpo["user_id"]
  end

  test "show devolve o assento" do
    get seat_url(seats(:livre))

    assert_response :success
    assert_equal seats(:livre).id, JSON.parse(response.body)["id"]
  end

  test "update altera os dados do assento" do
    patch seat_url(seats(:livre)), params: { seat: { price: 123.45 } }, as: :json

    assert_response :success
    assert_equal "123.45", JSON.parse(response.body)["price"]
  end

  test "destroy remove assento livre" do
    assert_difference "Seat.count", -1 do
      delete seat_url(seats(:livre))
    end

    assert_response :no_content
  end

  test "destroy recusa assento vendido" do
    assert_no_difference "Seat.count" do
      delete seat_url(seats(:vendido))
    end

    assert_response :unprocessable_entity
  end

  test "destroy recusa assento com item de pedido" do
    OrderItem.create!(order: orders(:one), seat: seats(:livre), price: 100.0)

    assert_no_difference "Seat.count" do
      delete seat_url(seats(:livre))
    end

    assert_response :unprocessable_entity
  end

  test "reserve reserva assento livre" do
    post reserve_seat_url(seats(:livre)), params: { user_id: users(:two).id }, as: :json

    assert_response :success
    corpo = JSON.parse(response.body)

    assert_equal "reservado", corpo["status"]
    assert_equal users(:two).id, corpo["user_id"]
    assert_not corpo["disponivel"]
    assert seats(:livre).reload.reservado?
  end

  test "reserve de assento já reservado responde 409" do
    post reserve_seat_url(seats(:reservado)), params: { user_id: users(:two).id }, as: :json

    assert_response :conflict
    assert_equal users(:one).id, seats(:reservado).reload.user_id
  end

  test "reserve de assento com reserva vencida funciona" do
    post reserve_seat_url(seats(:expirado)), params: { user_id: users(:one).id }, as: :json

    assert_response :success
    assert_equal users(:one).id, seats(:expirado).reload.user_id
  end

  test "reserve sem user_id responde 400" do
    post reserve_seat_url(seats(:livre)), params: {}, as: :json

    assert_response :bad_request
  end

  test "reserve com usuário inexistente responde 404" do
    post reserve_seat_url(seats(:livre)), params: { user_id: 999_999 }, as: :json

    assert_response :not_found
    assert seats(:livre).reload.livre?
  end

  test "release libera assento reservado" do
    post release_seat_url(seats(:reservado))

    assert_response :success
    corpo = JSON.parse(response.body)

    assert_equal "livre", corpo["status"]
    assert_nil corpo["user_id"]
    assert_nil corpo["reserved_until"]
  end

  test "release de assento vendido responde 409" do
    post release_seat_url(seats(:vendido))

    assert_response :conflict
    assert seats(:vendido).reload.vendido?
  end
end
