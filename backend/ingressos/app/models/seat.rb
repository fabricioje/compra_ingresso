class Seat < ApplicationRecord
  RESERVATION_TTL = 15.minutes

  belongs_to :event
  belongs_to :user, optional: true

  has_many :order_items, dependent: :restrict_with_error

  enum :status, { livre: 0, reservado: 1, vendido: 2 }

  validates :number, presence: true,
                     uniqueness: { scope: %i[event_id sector row] }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # expiradas, disponiveis e disponivel? compartilham o mesmo invariante:
  # reserved_until no passado conta como disponível. Mexeu em um, revise os
  # outros dois — foi por não reconferir esse invariante dentro da trava que
  # o job de limpeza chegou a derrubar reservas novas (ver release_if_expired!).
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

  # Usado pelo job de limpeza. Diferente de release!, reconfere dentro do
  # with_lock que a reserva CONTINUA vencida antes de liberar: o SELECT que
  # monta o lote (Seat.expiradas.find_each) roda fora de qualquer trava, então
  # entre essa leitura e o with_lock uma reserva nova pode ter sido feita. Se
  # o assento não estiver mais numa reserva vencida, não faz nada e retorna
  # true — não é uma recusa, é a reserva nova vencendo a corrida.
  def release_if_expired!(at = Time.current)
    with_lock do
      next true unless reservado? && reserved_until.present? && reserved_until < at

      update(status: :livre, user: nil, reserved_until: nil)
    end
  end
end
