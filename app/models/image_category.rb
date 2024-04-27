# frozen_string_literal: true

# == Schema Information
#
# Table name: image_categories
#
#  id         :integer          not null, primary key
#  owner_id   :integer
#  owner_type :string(255)
#  label      :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class ImageCategory < ApplicationRecord
  include Sanitizable

  sanitize_fields :label

  belongs_to :owner, polymorphic: true

  has_many :graph_images, -> { where(deactivated: false) }, dependent: :nullify

  validates :label, presence: true, uniqueness: { scope: :owner }

  delegate :customer, to: :owner
  delegate :customer_id, to: :owner

  def as_json(_options = {})
    super(only: %i[id label])
  end
end
