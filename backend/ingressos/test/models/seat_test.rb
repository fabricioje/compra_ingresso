require "test_helper"

class SeatTest < ActiveSupport::TestCase
  test "exige número" do
    seat = Seat.new(event: events(:one), sector: "C", row: "1")

    assert_not seat.valid?
    assert_includes seat.errors[:number], "can't be blank"
  end

  test "número é único por evento, setor e fileira" do
    duplicado = Seat.new(event: events(:one), sector: "A", row: "1", number: "1")

    assert_not duplicado.valid?
  end

  test "mesmo número em outro setor é válido" do
    seat = Seat.new(event: events(:one), sector: "Z", row: "1", number: "1")

    assert seat.valid?
  end

  test "mesmo número em outro evento é válido" do
    seat = Seat.new(event: events(:two), sector: "B", row: "1", number: "3")

    assert seat.valid?
  end

  test "preço não pode ser negativo" do
    seat = Seat.new(event: events(:one), sector: "C", row: "1", number: "9", price: -1)

    assert_not seat.valid?
  end

  test "preço pode ser nulo" do
    seat = Seat.new(event: events(:one), sector: "C", row: "1", number: "9")

    assert seat.valid?
  end

  test "assento livre está disponível" do
    assert seats(:livre).disponivel?
  end

  test "reserva dentro do prazo não está disponível" do
    assert_not seats(:reservado).disponivel?
  end

  test "reserva vencida está disponível" do
    assert seats(:expirado).disponivel?
  end

  test "assento vendido não está disponível" do
    assert_not seats(:vendido).disponivel?
  end

  test "reservado sem prazo não está disponível" do
    seat = seats(:reservado)
    seat.update_column(:reserved_until, nil)

    assert_not seat.disponivel?
  end

  test "scope expiradas traz só a reserva vencida" do
    assert_equal [ seats(:expirado) ], Seat.expiradas.to_a
  end

  test "scope disponiveis traz livre e expirado do evento" do
    disponiveis = events(:one).seats.disponiveis

    assert_includes disponiveis, seats(:livre)
    assert_includes disponiveis, seats(:expirado)
    assert_not_includes disponiveis, seats(:reservado)
  end

  test "reserve! reserva assento livre" do
    seat = seats(:livre)

    assert seat.reserve!(users(:two))
    assert seat.reservado?
    assert_equal users(:two), seat.user
    assert seat.reserved_until > Time.current
  end

  test "reserve! respeita o ttl informado" do
    seat = seats(:livre)

    freeze_time do
      seat.reserve!(users(:two), ttl: 5.minutes)

      assert_equal 5.minutes.from_now.to_i, seat.reserved_until.to_i
    end
  end

  test "reserve! recusa assento com reserva válida e preserva o dono" do
    seat = seats(:reservado)

    assert_not seat.reserve!(users(:two))
    assert_equal users(:one), seat.reload.user
    assert_not_empty seat.errors[:base]
  end

  test "reserve! assume assento com reserva vencida" do
    seat = seats(:expirado)

    assert seat.reserve!(users(:one))
    assert_equal users(:one), seat.reload.user
    assert seat.reserved_until > Time.current
  end

  test "reserve! recusa assento vendido" do
    seat = seats(:vendido)

    assert_not seat.reserve!(users(:one))
    assert seat.reload.vendido?
  end

  test "release! libera assento reservado" do
    seat = seats(:reservado)

    assert seat.release!
    assert seat.reload.livre?
    assert_nil seat.user
    assert_nil seat.reserved_until
  end

  test "release! é idempotente em assento livre" do
    seat = seats(:livre)

    assert seat.release!
    assert seat.reload.livre?
  end

  test "release! recusa assento vendido" do
    seat = seats(:vendido)

    assert_not seat.release!
    assert seat.reload.vendido?
    assert_not_empty seat.errors[:base]
  end

  test "release_if_expired! libera reserva ainda vencida" do
    seat = seats(:expirado)

    assert seat.release_if_expired!
    assert seat.reload.livre?
    assert_nil seat.user
    assert_nil seat.reserved_until
  end

  test "release_if_expired! não derruba reserva feita depois da leitura do lote" do
    # Reproduz a corrida do job: Seat.expiradas.find_each lê o registro FORA
    # de qualquer trava. Aqui materializamos esse mesmo lote, depois fazemos
    # uma reserva nova de verdade e só então chamamos release_if_expired! nos
    # objetos já carregados — exatamente a ordem em que a corrida acontecia.
    lote = Seat.expiradas.to_a

    seats(:expirado).reserve!(users(:one))

    lote.each(&:release_if_expired!)

    assert seats(:expirado).reload.reservado?
    assert_equal users(:one), seats(:expirado).user
  end

  test "release_if_expired! não mexe em reserva dentro do prazo" do
    seat = seats(:reservado)

    assert seat.release_if_expired!
    assert seat.reload.reservado?
    assert_equal users(:one), seat.user
  end
end
