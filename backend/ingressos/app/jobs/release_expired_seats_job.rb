# Higiene do banco: a expiração em si já é tratada na leitura (Seat#disponivel?
# e o scope Seat.disponiveis), então atrasar ou perder uma execução não muda o
# comportamento da API. O SELECT de Seat.expiradas roda fora de qualquer trava,
# por isso cada assento é liberado com release_if_expired!, que reconfere a
# expiração dentro do with_lock antes de gravar.
class ReleaseExpiredSeatsJob < ApplicationJob
  queue_as :default

  def perform
    Seat.expiradas.find_each(&:release_if_expired!)
  end
end
