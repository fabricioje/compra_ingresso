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
end
