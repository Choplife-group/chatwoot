# Choplife fork: least-busy assignment and agent capacity now have our own CE backend
# (AutoAssignment::LeastBusySelector, AutoAssignment::CapacityFilter, CapacityPolicy), so turn them on.
class ChopwinEnableAdvancedAssignment < ActiveRecord::Migration[7.2]
  def up
    Account.find_each { |account| account.enable_features!('advanced_assignment') }
  end

  def down
    # Feature flags are data; nothing to revert.
  end
end
