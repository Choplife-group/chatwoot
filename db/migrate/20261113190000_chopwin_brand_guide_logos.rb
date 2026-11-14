# Choplife fork: switch logos to the Chopwin brand guide artwork.
# Only rows still on the previous Chopwin default are changed; admin customisations are kept.
class ChopwinBrandGuideLogos < ActiveRecord::Migration[7.2]
  PREVIOUS = '/brand-assets/chopwin_icon.png'.freeze
  LOGOS = {
    'LOGO_THUMBNAIL' => '/brand-assets/chopwin_icon.svg',
    'LOGO' => '/brand-assets/chopwin_logo.svg',
    'LOGO_DARK' => '/brand-assets/chopwin_logo_dark.svg'
  }.freeze

  def up
    LOGOS.each do |name, value|
      config = InstallationConfig.find_by(name: name)
      next if config.nil? || config.value != PREVIOUS

      config.value = value
      config.save!
    end
    GlobalConfig.clear_cache
  end

  def down
    # Branding is data; nothing to revert.
  end
end
