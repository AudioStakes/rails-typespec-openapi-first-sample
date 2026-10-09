class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string :title, null: false
      t.string :status, null: false, default: "todo"
    end

    add_check_constraint :tasks, "length(CAST(title AS BLOB)) > 0", name: "tasks_title_not_empty"
    add_check_constraint :tasks, "status IN ('todo', 'doing', 'done')", name: "tasks_status"
  end
end
