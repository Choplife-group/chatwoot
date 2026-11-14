# Choplife fork: Help Center, Campaigns and Companies aren't part of Chopwin's support workflow.
# New accounts get them off via config/features.yml; this turns them off on existing accounts.
# They can be turned back on per account in Super Admin.
class ChopwinDisableUnusedFeatures < ActiveRecord::Migration[7.2]
  FEATURES = %w[help_center campaigns companies].freeze

  def up
    Account.find_each { |account| account.disable_features!(*FEATURES) }
  end

  def down
    # Feature flags are data; nothing to revert.
  end
end
