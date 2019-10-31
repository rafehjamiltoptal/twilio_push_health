class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.string  :email, index: true
      t.string  :password
      t.string  :first_name
      t.string  :last_name
      t.string  :phone_number, null: true
      t.string  :verification_code, null: true
      t.boolean :enable_sms, default: false
      t.boolean :verified, default: false

      t.timestamps
    end
  end
end
