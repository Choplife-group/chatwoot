# Choplife fork: the Help Center is back as players' self-service FAQ, linked from each website widget.
# 20261114090000 turned it off on existing accounts; this turns it back on. Campaigns and Companies stay off.
class ChopwinEnableHelpCenter < ActiveRecord::Migration[7.2]
  def up
    Account.find_each { |account| account.enable_features!('help_center') }
  end

  def down
    # Feature flags are data; nothing to revert.
  end
end
