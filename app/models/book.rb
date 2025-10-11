class Book < ApplicationRecord
  enum :status, { unread: 0, reading: 1, done: 2 }

  validates :title,  presence: true
  validates :author, presence: true
end
