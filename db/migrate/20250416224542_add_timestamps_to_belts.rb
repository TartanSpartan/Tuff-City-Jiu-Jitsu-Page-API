class AddTimestampsToBelts < ActiveRecord::Migration[8.0]
  def change
    add_timestamps :belts
  end
end