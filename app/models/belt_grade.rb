class BeltGrade < ApplicationRecord
    belongs_to :user, optional: true
    belongs_to :belt
    has_one :instructor_qualifications, dependent: :nullify
    has_many :techniques

    # validates :user, presence: true, uniqueness: true
end