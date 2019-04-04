class ChangeRetirementWarnToBeDateTime < ActiveRecord::Migration[5.0]
  def change
    change_column :vms, :retirement_warn, :datetime
    change_column :services, :retirement_warn, :datetime
    change_column :orchestration_stacks, :retirement_warn, :datetime
    change_column :load_balancers, :retirement_warn, :datetime
  end
end
