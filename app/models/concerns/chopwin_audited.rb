# Choplife fork: Settings → Audit logs on the CE build: admin, access and settings changes, plus
# conversation deletions. Everyday conversation actions (assign, VIP, category, resolve) are already logged
# inside each conversation. enterprise/ audits these models itself, so this does nothing when it is present.
module ChopwinAudited
  extend ActiveSupport::Concern

  TIMESTAMPS = %w[created_at updated_at].freeze
  OPTIONS = {
    'Account' => { only: %w[name locale domain support_email auto_resolve_duration status] },
    'AccountUser' => { associated_with: :account, except: TIMESTAMPS + %w[active_at inviter_id] },
    'Webhook' => { associated_with: :account, except: TIMESTAMPS + %w[secret] },
    'Conversation' => { associated_with: :account, on: [:destroy] }
  }.freeze
  # Join records reach their account through their parent. When the parent itself is being deleted,
  # its own audit covers it, so the memberships removed with it aren't audited.
  PARENTS = { 'TeamMember' => :team, 'InboxMember' => :inbox }.freeze

  included do
    next if ChatwootApp.enterprise?

    parent = PARENTS[name]
    define_method(:account) { public_send(parent)&.account } if parent

    options = OPTIONS.fetch(name) { { associated_with: :account, except: TIMESTAMPS } }
    options = options.merge(if: parent) if parent
    audited(**options)
  end
end
