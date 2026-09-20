class Seat < ApplicationRecord
  belongs_to :event
  belongs_to :user, optional: true

  enum :status, { livre: 0, reservado: 1, vendido: 2 }
end
