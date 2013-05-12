class ChangePreviewFormatInMyTable < ActiveRecord::Migration
  def up
  	change_column :articles, :preview, :text
  end

  def down
  	change_column :articles, :preview, :string
  end
end
