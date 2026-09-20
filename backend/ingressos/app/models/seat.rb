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

  # with_lock recarrega o registro dentro de um SELECT ... FOR UPDATE, então
  # duas requisições simultâneas no mesmo assento são serializadas: a segunda
  # só lê o estado depois que a primeira comitou.
  def reserve!(user, ttl: RESERVATION_TTL)
    with_lock do
      unless disponivel?
        errors.add(:base, "Assento indisponível")
        next false
      end

      update(status: :reservado, user: user, reserved_until: ttl.from_now)
    end
  end

  def release!
    with_lock do
      if vendido?
        errors.add(:base, "Assento vendido não pode ser liberado")
        next false
      end

      update(status: :livre, user: nil, reserved_until: nil)
    end
  end
end
