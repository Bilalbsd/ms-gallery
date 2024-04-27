# frozen_string_literal: true

# == Schema Information
#
# Table name: graph_images
#
#  id                :integer          not null, primary key
#  owner_id          :integer
#  owner_type        :string(255)
#  title             :string(255)
#  file              :string(255)
#  image_category_id :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  deactivated       :boolean          default(FALSE)
#

class GraphImage < ApplicationRecord
  # For elasticsearch
  include SearchableGraphImage

  mount_uploader :file, ImageUploader
  attr_accessor :crop_x, :crop_y, :crop_w, :crop_h

  has_many :elements, -> { where(type: :image) }

  belongs_to :owner, polymorphic: true
  belongs_to :image_category, optional: true

  scope :unclassified_images, -> { where(image_category_id: nil) }

  delegate :customer, to: :owner
  delegate :customer_id, to: :owner

  def absolute_url(version)
    File.join("public", file_url(version.to_sym))
  end

  def crop_image(p_crop_x, p_crop_y, p_crop_w, p_crop_h)
    self.crop_x = p_crop_x.to_i
    self.crop_y = p_crop_y.to_i
    self.crop_w = p_crop_w.to_i
    self.crop_h = p_crop_h.to_i

    file.recreate_versions!
  end

  def as_json(_options = {})
    super(only: %i[id title image_category_id])
  end

  def orderered_elements
    elements.includes(:graph).where.not(graphs: { state: "archived" })
            .order("graphs.level", "graphs.title")
  end

  def linked_graphs
    graphs = {}
    orderered_elements.each { |e| graphs[e.graph] = nil } # kind of ordered set
    graphs.keys
  end

  #
  # Returns image file path depending on the given `version`
  #
  # @param [Symbol, nil] version Desired image version
  #
  # @return [String] File path for the requested image
  #
  def image_path(version: nil)
    return file.path if version.nil? || !%i[preview show].include?(version.to_sym)

    file.public_send(version.to_sym).path
  end
end
