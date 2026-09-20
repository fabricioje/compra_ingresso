class Seat < ApplicationRecord
  belongs_to :event
  belongs_to :user, optional: true

  has_many :order_items, dependent: :restrict_with_error

  enum :status, { livre: 0, reservado: 1, vendido: 2 }
end
