# frozen_string_literal: true

module Gallery
  class ImagesController < ApplicationController
    before_action :load_settings, except: %i[show user_gallery]

    # located on public/uploads
    after_action :verify_authorized, except: %i[new user_gallery confirm_move]

    rescue_from ActionController::MissingFile,
                ActiveRecord::RecordNotFound,
                with: :handle_missing_image

    def crop
      @graph_image = @settings.graph_images.find(params[:id])
      authorize @graph_image
    end

    def show
      graph_image = GraphImage.find(params[:id])
      authorize graph_image

      send_file(
        graph_image.image_path(version: params[:version]),
        disposition: "inline",
        x_sendfile: true
      )
    end

    # action for user gallery tab
    def user_gallery; end

    def new
      @category = @settings.image_categories.find(params[:image_category_id]) unless params[:image_category_id].nil?
    end

    # TODO: Simplify using early error returns with guard clause
    # rubocop:disable Metrics/AbcSize
    def create
      @category = @settings.image_categories.find(params[:image_category_id]) unless params[:image_category_id].nil?

      authorize @settings.graph_images.new
      if params[:customer_setting]
        graph_imgs = params[:customer_setting][:graph_images]
        graph_imgs.each do |file|
          logger.debug @category.to_s
          @settings.graph_images.create(
            image_category_id: (@category.nil? ? nil : @category.id),
            file: file,
            title: file.original_filename
          )
        end
        flash[:success] = t(".success")
      else
        flash[:warning] = t(".warning")
      end

      respond_to do |format|
        format.html {}
        format.js {}
      end
    end
    # rubocop:enable Metrics/AbcSize

    def confirm_move
      @categories = @settings.image_categories.all
      @current_category = params[:current_category]
    end

    # rubocop:disable Metrics/AbcSize
    def move
      authorize @settings.graph_images.new
      @category = @settings.image_categories.find(params[:parent_id])

      images_array = params[:image_ids].split(",")
      @current_category = @settings.graph_images.where(id: images_array.first).first.image_category

      if images_array.any?
        @settings.graph_images.where(id: images_array).update_all(image_category_id: @category.id)
        flash[:success] = t(".success")
      else
        flash[:warning] = t(".warning")
      end
    end
    # rubocop:enable Metrics/AbcSize

    def destroy_all
      authorize @settings.graph_images.new

      images_array = params[:image_ids].split(",")
      @current_category = @settings.graph_images.where(id: images_array.first).first.image_category

      if images_array.any?
        @settings.graph_images.where(id: images_array).update_all(deactivated: true)
        flash[:success] = t(".success")
      else
        flash[:warning] = t(".warning")
      end
    end

    # TODO: Simplify by moving some instance variable settings to private
    # methods
    # rubocop:disable Metrics/AbcSize
    def update
      authorize @settings.graph_images.new
      @graph_image = @settings.graph_images.find(params[:id])
      @current_category = @graph_image.image_category

      unless crop_coords_blank?
        @graph_image.crop_image(image_params[:crop_x], image_params[:crop_y],
                                image_params[:crop_w], image_params[:crop_h])
      end

      @graph_image.update_attributes(title: image_params[:title]) unless title_blank?

      if title_blank? && crop_coords_blank?
        flash[:warning] = t(".warning")
      else
        flash[:success] = t(".success")
      end
    end
    # rubocop:enable Metrics/AbcSize

    private

    # Crop coords are blank if any of the crop reactangle points (x, y, width or
    # height) are blank
    def crop_coords_blank?
      image_params[:crop_x].blank? || image_params[:crop_y].blank? ||
        image_params[:crop_w].blank? || image_params[:crop_h].blank?
    end

    def image_params
      params[:graph_image]
    end

    # Load the current customer's settings into `@settings`
    def load_settings
      @settings = current_customer.settings
    end

    # Title is blank if the title parameter was not set or if it is the same as
    # the current graph_image title
    def title_blank?
      image_params[:title].blank? || image_params[:title] == @graph_image.title
    end

    #
    # Responds to missing images with a `404`
    #
    # @return [void]
    #
    def handle_missing_image
      send_file(
        Rails.root.join("public", "404.html"),
        status: :not_found,
        type: "text/html; charset=utf-8"
      )
    end
  end
end
