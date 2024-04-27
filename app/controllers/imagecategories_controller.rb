# frozen_string_literal: true

class Gallery::ImagecategoriesController < ApplicationController
  after_action :verify_authorized, except: [:search]

  def index
    @settings = current_customer.settings
    @new_category = @settings.image_categories.new
    authorize @new_category
    @categories = @settings.image_categories.all
    @all = params[:category] == "all"
    flag = @all ? true : false

    respond_to do |format|
      format.html {}
      format.json do
        render json: {
          categories: @categories,
          images: @all ? @settings.graph_images : @settings.graph_images.unclassified_images,
          search_url: search_gallery_imagecategory_path(0, all: flag, format: "json")
        }
      end
    end
  end

  def designer_index
    @settings = current_customer.settings
    @new_category = @settings.image_categories.new
    authorize @new_category
    @categories = @settings.image_categories.all
    @all = params[:category] == "all"
    flag = @all ? true : false

    respond_to do |format|
      format.html {}
      format.json do
        render json: {
          categories: @categories,
          images: @all ? @settings.graph_images : @settings.graph_images.unclassified_images,
          search_url: search_gallery_imagecategory_path(0, all: flag, format: "json")
        }
      end
    end
  end

  def images
    @settings = current_customer.settings
    @new_category = @settings.image_categories.new
    @categories = @settings.image_categories.all
    @current_category = @settings.image_categories.find(params[:id])
    authorize @current_category

    respond_to do |format|
      format.html {}
      format.json do
        render json: {
          images: @current_category.graph_images,
          search_url: search_gallery_imagecategory_path(params[:id], format: "json")
        }
      end
    end
  end

  def designer_images
    @settings = current_customer.settings
    @new_category = @settings.image_categories.new
    @categories = @settings.image_categories.all
    @current_category = @settings.image_categories.find(params[:id])
    authorize @current_category

    respond_to do |format|
      format.html {}
      format.json do
        render json: {
          images: @current_category.graph_images,
          search_url: search_gallery_imagecategory_path(params[:id], format: "json")
        }
      end
    end
  end

  # rubocop:disable Metrics/AbcSize
  def search
    @term = params[:term]
    @all = params[:all] == "true"

    @category = (current_customer.settings.image_categories.find(params[:id]) if params[:id].to_i != 0)

    @images = if @category.nil? && @all
                GraphImage.search(@term, current_customer.id).records
              else
                GraphImage.search_from_category(@term, current_customer.id, @category.nil? ? nil : @category.id).records
              end

    respond_to do |format|
      format.js do
        render "search_no_result" if @images.blank?
      end
      format.json do
        render json: {
          term: sanitize_this(@term),
          images: @images
        }
      end
    end
  end
  # rubocop:enable Metrics/AbcSize

  def create
    @settings = current_customer.settings
    authorize @settings.image_categories.new
    @category = @settings.image_categories.new(image_categories_params)

    if @category.save
      flash_x_success t(".success")
    else
      flash_x_error @category.errors.messages.values.join("<br>")
    end
  end

  def destroy
    @settings = current_customer.settings
    @category = @settings.image_categories.find(params[:id])
    authorize @category

    flash[:success] = t(".success") if @category.destroy
  end

  def update
    @settings = current_customer.settings
    @category = @settings.image_categories.find(params[:id])
    authorize @category

    flash_x_success t(".success") if @category.update_attributes(image_categories_params)
  end

  private

  def image_categories_params
    params.require(:image_category).permit(:label)
  end

  def user_not_authorized
    respond_to do |format|
      format.html { redirect_to root_path }
      format.js { render js: "window.location.replace('#{root_path}')" }
    end
  end
end
