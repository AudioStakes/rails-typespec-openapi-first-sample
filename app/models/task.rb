class Task < ApplicationRecord
  validates :title, length: { minimum: 1, maximum: 100 }
  validates :status, inclusion: { in: %w[todo doing done] }
end
