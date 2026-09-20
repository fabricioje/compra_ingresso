class Event < ApplicationRecord
  has_many :seats, dependent: :destroy
end
