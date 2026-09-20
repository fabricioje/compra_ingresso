class User < ApplicationRecord
  has_many :orders, dependent: :destroy
  has_many :seats, dependent: :nullify

  has_secure_password

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
end
