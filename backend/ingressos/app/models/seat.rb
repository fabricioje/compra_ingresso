class Seat < ApplicationRecord
  RESERVATION_TTL = 15.minutes

  belongs_to :event
  belongs_to :user, optional: true

  has_many :order_items, dependent: :restrict_with_error

  enum :status, { livre: 0, reservado: 1, vendido: 2 }

  validates :number, presence: true,
                     uniqueness: { scope: %i[event_id sector row] }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :expiradas, -> { reservado.where(reserved_until: ...Time.current) }
  scope :disponiveis, -> { livre.or(expiradas) }

  # Um assento reservado sem prazo nunca expira sozinho: só o release! o devolve.
  def disponivel?(at = Time.current)
    return true if livre?

    reservado? && reserved_until.present? && reserved_until < at
  end
end
