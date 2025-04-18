class Belt < ApplicationRecord
  has_many :belt_grades, dependent: :destroy
  has_many :instructor_qualifications, dependent: :nullify
  has_many :qualifications, dependent: :nullify
  # has_many :techniques
  has_many :technique_types
  belongs_to :syllabus, optional: true
  
  validates :colour, presence: true

  def capitalize_colour
    self.colour.capitalize!
  end
end