require "test_helper"

class ReleaseExpiredSeatsJobTest < ActiveJob::TestCase
  test "devolve para livre as reservas vencidas" do
    ReleaseExpiredSeatsJob.perform_now

    expirado = seats(:expirado).reload

    assert expirado.livre?
    assert_nil expirado.user
    assert_nil expirado.reserved_until
  end

  test "não toca em reserva dentro do prazo nem em vendido" do
    ReleaseExpiredSeatsJob.perform_now

    assert seats(:reservado).reload.reservado?
    assert_equal users(:one), seats(:reservado).user
    assert seats(:vendido).reload.vendido?
  end
end
