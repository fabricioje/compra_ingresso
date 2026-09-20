class AddIndexesToSeats < ActiveRecord::Migration[8.1]
  def change
    # Sustenta o SELECT recorrente de Seat.expiradas (status = 1 e
    # reserved_until vencido), que hoje varre a tabela inteira a cada minuto.
    add_index :seats, :reserved_until, where: "status = 1", name: "index_seats_on_expiring_reservations"

    # Sustenta o filtro ?status= combinado com o event_id do index.
    add_index :seats, [ :event_id, :status ]

    # Dá suporte no banco à validação de unicidade de number, que hoje só
    # existe em Ruby e não impede duplicatas sob create concorrente.
    add_index :seats, [ :event_id, :sector, :row, :number ], unique: true
  end
end
