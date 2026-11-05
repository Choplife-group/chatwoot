# == Schema Information
#
# Table name: conversation_categories
#
#  id           :bigint           not null, primary key
#  ancestor_ids :integer          default([]), not null, is an Array
#  archived_at  :datetime
#  depth        :integer          default(1), not null
#  name         :string           not null
#  position     :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  parent_id    :bigint
#
# Indexes
#
#  idx_on_account_id_parent_id_name_589e5e71b2    (account_id,parent_id,name) UNIQUE
#  index_conversation_categories_on_ancestor_ids  (ancestor_ids) USING gin
#
# Reason for contact, e.g. "Withdrawal › Pending approval". Admins manage the tree (up to MAX_DEPTH levels);
# agents pick a leaf on each conversation. Nodes never move to another parent, so ancestor_ids is set once on create.
class ConversationCategory < ApplicationRecord
  MAX_DEPTH = 5
  PATH_SEPARATOR = ' › '.freeze

  belongs_to :account
  belongs_to :parent, class_name: 'ConversationCategory', optional: true
  has_many :children, class_name: 'ConversationCategory', foreign_key: :parent_id, dependent: :restrict_with_error, inverse_of: :parent
  has_many :conversations, foreign_key: :category_id, dependent: :restrict_with_error, inverse_of: :category

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(:depth, :position, :name) }

  validates :name, presence: true, uniqueness: { scope: [:account_id, :parent_id] }
  validates :depth, numericality: { less_than_or_equal_to: MAX_DEPTH }
  validate :parent_in_same_account
  validate :parent_unchanged, on: :update

  before_validation :set_tree_position, on: :create
  before_validation { self.name = name.strip if name.present? }

  # The ids of these categories and every category below them, for filtering by any level
  def self.subtree_ids(account, ids)
    ids = Array(ids).map(&:to_i)
    account.conversation_categories.where(id: ids).or(account.conversation_categories.where('ancestor_ids && ARRAY[?]::integer[]', ids)).pluck(:id)
  end

  def archived?
    archived_at.present?
  end

  def leaf?
    children.active.none?
  end

  def path_names
    ancestors.map(&:name) + [name]
  end

  def path
    path_names.join(PATH_SEPARATOR)
  end

  def push_event_data
    { id: id, name: name, ancestor_ids: ancestor_ids, path: path }
  end

  private

  def ancestors
    return [] if ancestor_ids.empty?

    self.class.where(id: ancestor_ids).index_by(&:id).values_at(*ancestor_ids)
  end

  def set_tree_position
    self.depth = parent ? parent.depth + 1 : 1
    self.ancestor_ids = parent ? parent.ancestor_ids + [parent.id] : []
  end

  def parent_in_same_account
    errors.add(:parent_id, :invalid) if parent && parent.account_id != account_id
  end

  def parent_unchanged
    errors.add(:parent_id, :invalid) if parent_id_changed?
  end
end
