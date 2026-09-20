class Seat < ApplicationRecord
  belongs_to :event
  belongs_to :user, optional: true

  has_many :order_items, dependent: :restrict_with_error

  enum :status, { livre: 0, reservado: 1, vendido: 2 }

  validates :number, presence: true,
                     uniqueness: { scope: %i[event_id sector row] }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
