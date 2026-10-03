# Choplife fork: rebrand existing installations to Chopwin.
#
# ConfigLoader only inserts configs that don't exist yet (reconcile_only_new), so the new
# defaults in config/installation_config.yml never reach databases seeded with the stock
# Chatwoot values. This flips each branding row to the Chopwin value ONLY while it still holds
# the upstream default — anything an admin already customised is left alone — and unlocks the
# rows so they are editable in /super_admin/installation_configs.
class ChoplifeBrandingDefaults < ActiveRecord::Migration[7.2]
  UPSTREAM_TO_CHOPWIN = {
    'INSTALLATION_NAME' => ['Chatwoot', 'Chopwin Support'],
    'LOGO_THUMBNAIL' => ['/brand-assets/logo_thumbnail.svg', '/brand-assets/chopwin_icon.png'],
    'LOGO' => ['/brand-assets/logo.svg', '/brand-assets/chopwin_icon.png'],
    'LOGO_DARK' => ['/brand-assets/logo_dark.svg', '/brand-assets/chopwin_icon.png'],
    'BRAND_URL' => ['https://www.chatwoot.com', 'https://chopwin.com'],
    'WIDGET_BRAND_URL' => ['https://www.chatwoot.com', 'https://chopwin.com'],
    'BRAND_NAME' => ['Chatwoot', 'Chopwin']
  }.freeze

  UNLOCK = (UPSTREAM_TO_CHOPWIN.keys + %w[TERMS_URL PRIVACY_URL DISPLAY_MANIFEST]).freeze

  def up
    UPSTREAM_TO_CHOPWIN.each do |name, (upstream, chopwin)|
      config = InstallationConfig.find_by(name: name)
      next if config.nil?

      config.value = chopwin if config.value == upstream
      config.locked = false
      config.save!
    end
    InstallationConfig.where(name: UNLOCK - UPSTREAM_TO_CHOPWIN.keys).update_all(locked: false)
    GlobalConfig.clear_cache
  end

  def down
    # Branding is data; nothing to revert.
  end
end
