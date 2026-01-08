class MakeTechniqueTypeSubCategoryNullable < ActiveRecord::Migration[6.0]
  def up
    change_column_null :technique_types, :sub_category, true
  end

  def down
    # Replace NULLs with empty string before making not-null to avoid failures.
    TechniqueType.where(sub_category: nil).update_all(sub_category: "")
    change_column_null :technique_types, :sub_category, false
  end
end
