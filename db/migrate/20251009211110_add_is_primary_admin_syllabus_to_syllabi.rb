class AddIsPrimaryAdminSyllabusToSyllabi < ActiveRecord::Migration[8.0]
  def change
    add_column :syllabi, :is_primary_admin_syllabus, :boolean, default: false
  end
end
