class Order < ApplicationRecord
  belongs_to :user
  has_many :order_items, dependent: :destroy

  enum :status, { pendente: 0, pago: 1, cancelado: 2, expirado: 3 }
end
