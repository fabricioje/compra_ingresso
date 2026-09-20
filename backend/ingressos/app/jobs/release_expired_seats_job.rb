# Higiene do banco: a expiração em si já é tratada na leitura (Seat#disponivel?),
# então atrasar ou perder uma execução não muda o comportamento da API.
class ReleaseExpiredSeatsJob < ApplicationJob
  queue_as :default

  def perform
    Seat.expiradas.find_each { |seat| seat.release! }
  end
end
