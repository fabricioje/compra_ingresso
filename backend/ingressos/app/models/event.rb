class Event < ApplicationRecord
  has_many :seats, dependent: :destroy

  validates :name, presence: true
  validates :date, presence: true
end
