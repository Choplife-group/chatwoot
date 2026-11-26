# Choplife fork: our CE image has no enterprise/, so audits go to our own AuditLog
# (config/initializers/audited.rb points at Enterprise::AuditLog). What gets audited: ChopwinAudited.
# Only sets a class name here; loading models this early would run their I18n.t calls before translations load.
Rails.application.config.to_prepare do
  Audited.audit_class = 'AuditLog' unless ChatwootApp.enterprise?
end
