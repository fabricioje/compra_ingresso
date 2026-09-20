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
end
