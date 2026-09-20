class RenameUsersPasswordToPasswordDigest < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :password, :password_digest

    # A validação de unicidade do model sozinha sofre race condition;
    # o índice garante no banco.
    add_index :users, :email, unique: true
  end
end
