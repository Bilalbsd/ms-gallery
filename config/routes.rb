# frozen_string_literal: true

require "sidekiq/web"

Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  mount Tolk::Engine => "/tolk", :as => "tolk" if Rails.env.development? || ENV.fetch("PYX4_TOLK", false)

  if Rails.env.development? || ENV.fetch("PYX4_GRAPHIQL", false)
    authenticate :user do
      mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "/graphql"
    end
  end

  resources :events, except: %i[edit] do
    collection do
      put "update_responsibilities"
      put "update_workflow"
    end
  end

  resources :acts, except: %i[edit] do
    collection do
      put "update_responsibilities"
      put "update_workflow"
    end
  end

  # Alias for `/acts` for correctness in front-end routes.
  resources :actions, controller: :acts, except: %i[edit] do
    collection do
      put "update_responsibilities"
      put "update_workflow"
    end
  end

  resources :audits, except: %i[edit] do
    member do
      post "duplicate"
    end

    collection do
      put "update_responsibilities"
      put "update_workflow"
    end
  end

  resources :audit_elements, only: %i[create update destroy]

  resource :missing_translations, only: [:create]

  post "/graphql", to: "graphql#execute"
  root to: "directories#index"

  get "/private/uploads/document/file/:id/:file_name",
      to: "documents#download", constraints: { file_name: /[^\\,\s]*\.\w{2,6}/ }

  # TODO: after release, move graph_images to private/uploads folder to make it semantically correct
  get "/public/uploads/graph_image/file/:id/:file_name",
      to: "gallery/images#show#show",
      constraints: { file_name: /[^\\,\s]*\.\w{2,6}/ }

  # Entity attachment download. This must come last after any other
  # `/private/uploads/` routes as the `:type` path parameter acts as a
  # catch-all.
  get "/private/uploads/:type/file/:id/:file_name",
      to: "improver/attachments#download", constraints: { file_name: /[^\\,\s]*\.\w{2,6}/ }

  get "generate_all_svg", to: "graphs#generate_all_svg"

  admin_constraints = if Settings.server.admin_subdomain.present?
                        { subdomain: Settings.server.admin_subdomain }
                      else
                        {}
                      end

  devise_for :super_admins,
             controllers: {
               sessions: "admin/sessions"
             },
             constraints: admin_constraints

  # scope :admin do
  namespace :admin, constraints: admin_constraints do
    get "graph_elements/:graph_id", to: "customers#graph_elements"
    post "generate_svg/:graph_id", to: "customers#generate_svg"
    get "reference_state", to: "customers#reference_state"
    resources :customers do
      member do
        patch "update_max_power_user"
        patch "update_max_simple_user"
        patch "update_max_graphs_and_docs"
        patch "update_account_type"
        patch "update_language"
        patch "update_owner"
        patch "update_contact"
        patch "update_improver"
        patch "update_risk_module"
        patch "update_migration"
        patch "update_store"
        patch "update_sso"
        patch "update_ldap"
        patch "update_deactivated"
        patch "update_deactivated_at"
        get "reveal_one_svg"
      end
      collection do
        get "generate_all_svg"
        get "general_settings"
        get "scan_instance"
        get "reveal_svg"
        get "export_pu"
        patch "update_general_settings_field"
      end
    end
  end
  # end

  # begin routes concerns

  concern :renamable do
    collection do
      patch "rename"
      get "rename_modal"
    end
  end

  concern :favorable do
    member do
      post "favor_one"
      post "unfavor_one"
    end
    collection do
      post "favor"
      post "unfavor"
    end
  end

  concern :logo do
    member do
      post "update_logo"
      get "serve_logo"
      get "crop_logo"
      get "confirm_delete_logo"
      patch "delete_logo"
      patch "update_crop_logo"
    end
  end

  concern :attachable do
    resources :attachments, only: %i[new create destroy] do
      member do
        get "confirm_destroy"
        get "download"
      end
    end
  end

  concern :activable do
    member do
      get "confirm_deactivate_one"
      get "reactivate"
      post "deactivate_one"
      post "reactivate_one"
    end

    collection do
      get "confirm_deactivate"
      post "deactivate"
    end
  end

  # @see UserAssignable concern
  concern :user_assignable do
    member do
      get "show_users"

      # Modal to assign users
      get "confirm_assign_users"
      post "assign_users"

      # Modal to confirm users unassignment
      get "confirm_unassign_users"
      post "unassign_users"
    end
  end
  # end routes concerns

  resources :graphimages
  resources :dashboard, only: [:index]

  resources :tasks do
    member do
      get "follow"
      get "mark_read"
    end

    collection do
      put "set_important"
      put "unset_important"
    end
  end

  namespace :parameters do
    resources :improver, only: [:index] do
      collection do
        get :responsibles, to: "spa#index"
        get :events, to: "spa#index"
        get :audits, to: "spa#index"
        get :actions, to: "spa#index"
      end
    end

    resources :localisations, only: %i[index destroy create]

    resources :criticalities, only: %i[destroy create update], path: :event_criticalities
  end

  resource :settings, only: %i[edit update], concerns: [:logo] do
    collection do
      get "user_import"
      get "user_csv_template"
      post "handle_user_import"

      get "general"
      post "change_time_zone"
      post "change_logo_usage"
      post "edit_print_footer"
      post "change_approved_read"
      post "update_colors"
      post "toggle_color"
      post "delete_color"
      get "colors"
      post "update_owner_users_management"
      patch "update_authentication_strategy"
      patch "update_referent_contact"
      patch "update_nickname"
      patch "update_password_policy"
      patch "update_user_deactivation"
      patch "update_deactivation_period"
      get "localisation_preference", to: "settings#show_localisation_preference"
    end
  end

  resource :sso_settings, only: %i[edit update]
  resources :ldap_settings do
    member do
      patch "activate"
    end
  end

  resources :users, only: [:index], concerns: [:attachable] do
    collection do
      get "search"
      get "edit_metadata" # , to: "users#edit_metadata", as: "user_edit_metadata"
      put "update_metadata" # , to: "users#update_metadata", as: "user_update_metadata"
      get "create_random" if Rails.env.development?
    end
    member do
      get "edit_avatar"
      get "interactions"
      patch "update_avatar"
      get "serve_avatar", to: "users#serve_avatar"
      get "crop_avatar"
      patch "update_crop_avatar"
    end
  end

  devise_for :users,
             controllers: {
               registrations: "registrations",
               invitations: "invitations",
               passwords: "passwords",
               saml_sessions: "users/saml_sessions",
               sessions: "sessions",
               omniauth_callbacks: "users/omniauth_callbacks"
             },
             skip: :saml_authenticatable

  devise_scope :user do
    get "/users/auth/ldap/setup" => "sessions#setup"
    get "/users/auth/ldap/login" => "logins#new" if Rails.env.test?
    get "users/edit_password", to: "registrations#edit_password"
    patch "users/update_password", to: "registrations#update_password"
    # profile type
    # put 'users/:id/update_profile_type', :to => 'registrations#update_profile_type'
    get "users/:id/edit_profile_type", to: "registrations#edit_profile_type", as: "edit_user_profile_type"
    get "users/:id/update_instance_ownership",
        to: "registrations#update_instance_ownership",
        as: "update_instance_ownership"
    post "users/:id/rights", to: "registrations#transfer_rights", as: "edit_user_transfer_rights"
    # end profile type
    get "users/:id/edit" => "registrations#edit", :as => "edit_user"
    put "users/:id" => "registrations#update", :as => "put_user"
    get "users/confirm_deactivation" => "registrations#confirm_deactivation", :as => "confirm_deactivation"
    post "users/deactivate", to: "registrations#deactivate", as: "deactivate_user"
    post "users/:id/invite", to: "invitations#send_invitation", as: "invite_user"
    post "users/invite_all", to: "invitations#send_all_invitations", as: "invite_all"
    post "users/:id/restore", to: "registrations#restore", as: "restore_user"
    post "users/:id/update_groups", to: "users#update_groups"
    get "users/:id/confirm_link_roles", to: "users#confirm_link_roles", as: "confirm_link_roles"
    post "users/:id/roles", to: "users#link_roles", as: "link_roles"
    delete "users/:id/roles", to: "users#unlink_roles", as: "unlink_roles"
    get "users/:id/roles/:role_id/graphs", to: "users#list_linked_graphs", as: "list_role_linked_graphs"
    post "users/:id/roles/graphs", to: "users#list_linked_graphs", as: "list_roles_linked_graphs"
    get "users/:id/oauth_callback", to: "registrations#oauth_callback"

    scope "users", controller: "saml_sessions" do
      get "saml/confirm_sign_in", to: "users/saml_sessions#confirm_sign_in"
      post "saml/confirm_sign_in", to: "users/saml_sessions#confirm_sign_in"
      get :new, path: "saml/sign_in", as: :new_user_sso_session, to: "users/saml_sessions#new"
      post :create, path: "saml/auth", as: :user_sso_session, to: "users/saml_sessions#create"
      get :destroy, path: "saml/sign_out", as: :destroy_user_sso_session, to: "users/saml_sessions#destroy"
      get :metadata, path: "saml/metadata", as: :metadata_user_sso_session, to: "users/saml_sessions#metadata"
    end

    scope "users", controller: "emergency_sessions" do
      get :confirm_link, as: :new_user_emergency_session, to: "users/emergency_sessions#confirm_link"
      patch :send_link, as: :user_emergency_send_link, to: "users/emergency_sessions#send_link"
      get :create, as: :user_emergency_session, to: "users/emergency_sessions#create"
    end
  end

  resources :notifications, concerns: :favorable do
    member do
      get "follow"
      patch "mark_read_old"
    end

    collection do
      get "preview"
      post "delete"
      patch "mark_read"
      patch "mark_all_read"
      patch "mark_unread"
    end
  end

  resources :groups, concerns: %i[renamable user_assignable] do
    collection do
      get "confirm_delete"
      post "delete"
    end
  end

  namespace :gallery do
    resources :images do
      collection do
        get "user"
        put "move"
        get "confirm_move"
        put "destroy_all"
      end
      member do
        get "crop"
      end
    end
    resources :imagecategories do
      member do
        get "images"
        post "search"
        get "designer_images"
      end
      collection do
        get "designer_index"
      end
    end
  end

  resources :roles, concerns: %i[renamable favorable attachable activable user_assignable] do
    member do
      get "show_properties"
      get "confirm_delete_one"
      get "print"
      get "interactions"
      post "delete_one"
      post "update_tags"
    end
    collection do
      get "linkable/:type", action: "linkable"
      post "in_referential", action: "in_referential"
      get "confirm_delete"
      get "confirm_rename"
      post "rename"
      post "delete"
    end
  end

  resources :groupgraphs do
    member do
      get "draw"
      get "renaissance"
      get "properties"
    end
  end

  resources :graphs, concerns: [:favorable] do
    resources :elements
    scope module: :graphs do
      resources :events
    end
    resources :contributors do
      collection do
        get "search"
      end
    end
    resources :contributions, only: %i[create update destroy]
    resources :roles
    resources :viewers, only: %i[create destroy] do
      collection do
        post "/groups/", to: "viewers#create_group", as: "create_group_for"
        delete "/groups/:id", to: "viewers#destroy_group", as: "delete_group_for"
        post "/roles/", to: "viewers#create_role", as: "create_role_for"
        delete "/roles/:id", to: "viewers#destroy_role", as: "delete_role_for"
      end
    end
    resources :verifiers, only: %i[create destroy] do
      member do
        post "accept"
        post "reject"
        post "admin_accept"
        post "admin_reject"
      end
    end
    resources :approvers, only: %i[create destroy] do
      member do
        post "approve", action: :accept
        post "disapprove", action: :reject
        post "admin_approve", action: :admin_accept
        post "admin_disapprove", action: :admin_reject
      end
    end
    resources :publisher, only: %i[create destroy] do
      member do
        post "publish", action: :accept
        post "admin_publish", action: :admin_accept
      end
    end
    resources :graph_backgrounds do
      collection do
        put "reset_background"
      end
    end

    member do
      get "reset" if Rails.env.development?
      get "unlock"
      get "lock"
      get "draw"
      get "renaissance"
      post "save"
      get "show_properties"
      get "confirm_move"
      post "move_graph"
      post "update_tags"
      get "actors"
      get "start_wf"
      get "confirm_increment_version"
      post "increment_version"
      get "confirm_historical_increment_version"
      post "historical_increment_version"
      get "diary"
      get "historical"
      get "confirm_delete"
      get "confirm_delete_version"
      post "delete_version"
      get "confirm_duplicate"
      patch "duplicate"
      get "confirm_author"
      get "confirm_pilot"
      post "author"
      post "pilot"
      post "update_root"
      post "generate_svg"
      patch "reset_svg"
      get "distribute"
      get "search_actors"
      get "svg"
      get "interactions"
      post "deactivate"
      post "activate"
      post "settings_print_footer"
      post "check_reference"
      get "list_read_confirmations"
      post "read_confirmation"
      put "send_read_confirmation_reminders"
      post "toggle_auto_role_viewer"
      post "toggle_review"
      post "update_review_date"
      post "update_review_reminder"
      post "complete_review"
      get "steps"
    end
    collection do
      post "update_model_list/:type/:level", action: "update_model_list"
      post "update_model_preview/:id", action: "update_model_preview"
      get "graphs_linkable"
      get "actors"
      get "graphs_list"
    end
  end

  resources :role_attachments, only: [:destroy] do
    member do
      get "download"
    end
  end

  resources :groupdocuments do
    member do
      get "draw"
      get "renaissance"
      get "properties"
      get "show_properties"
    end
  end

  resources :documents, concerns: [:favorable] do
    resources :pilot, only: %i[new edit create update]
    resources :viewers, only: %i[create destroy] do
      collection do
        post "/groups/", to: "viewers#create_group", as: "create_group_for"
        delete "/groups/:id", to: "viewers#destroy_group", as: "delete_group_for"
        post "/roles/", to: "viewers#create_role", as: "create_role_for"
        delete "/roles/:id", to: "viewers#destroy_role", as: "delete_role_for"
      end
    end
    resources :verifiers, only: %i[create destroy] do
      member do
        post "accept"
        post "reject"
        post "admin_accept"
        post "admin_reject"
      end
    end
    resources :approvers, only: %i[create destroy] do
      member do
        post "approve", action: :accept
        post "disapprove", action: :reject
        post "admin_approve", action: :admin_accept
        post "admin_disapprove", action: :admin_reject
      end
    end
    resources :publisher, only: %i[create destroy] do
      member do
        post "publish", action: :accept
        post "admin_publish", action: :admin_accept
      end
    end
    member do
      get "show_properties"
      get "confirm_move"
      get "unlock"
      get "lock"
      post "move_document"
      get "edit_actual_url"
      patch "update_actual_url"
      post "update_tags"
      get "actors"
      get "start_wf"
      get "diary"
      get "historical"
      get "confirm_increment_version"
      get "confirm_historical_increment_version"
      post "historical_increment_version"
      post "increment_version"
      get "confirm_destroy_groupdocument"
      get "confirm_author"
      post "author"
      get "search_actors"
      get "confirm_destroy_version"
      post "destroy_version"
      get "interactions"
      post "deactivate"
      post "activate"
      post "settings_print_footer"
      post "check_reference"
      get "list_read_confirmations"
      post "read_confirmation"
      put "send_read_confirmation_reminders"
    end
    collection do
      get "linkable"
      get "confirm_delete"
      post "delete"
    end
  end

  resources :tags do
    member do
      get "confirm_delete"
      get "confirm_rename"
      post "delete"
      post "rename"
    end
  end

  resources :favorites

  resources :directories, concerns: %i[renamable favorable] do
    collection do
      get "confirm_delete"
      get "confirm_move"
      post "set_parent_directory"
      post "delete_directories"
      post "move_directories"
    end
  end

  resources :resources, concerns: %i[renamable favorable logo activable] do
    member do
      get "show_properties"
      get "confirm_delete_one"
      post "delete_one"
      get "edit_url"
      patch "update_url"
      post "update_tags"
      get "absolute_url"
      get "interactions"
    end
    collection do
      get "linkable"
      get "confirm_delete"
      post "delete"
    end
  end

  resources :recordings do
    collection do
      get "linkable"
    end
  end

  registration_constraints = if Settings.server.registration_subdomain.present?
                               { subdomain: Settings.server.registration_subdomain }
                             else
                               {}
                             end
  scope "(/:locale)", defaults: { locale: I18n.default_locale }, locale: Regexp.new(I18n.available_locales.join("|")) do
    resources :signups, constraints: registration_constraints,
                        only: %i[create new]
  end

  post "repository/set_parent_directory" => "repository#set_parent_directory", :as => "repository/set_parent_directory"

  scope :search, controller: :search do
    post "header", as: :search_header
    post "improver_header", as: :improver_search_header
    get "all", as: :search_all
    get "graph", as: :search_graph
    get "document", as: :search_document
    get "directory", as: :search_directory
    get "tag", as: :search_tag
    get "role", as: :search_role
    get "resource", as: :search_resource
    get "user", as: :search_user
    get "group", as: :search_group
  end

  get "print_preferences" => "print#preferences", :as => "print_preferences"
  post "print" => "print#print", :as => "print"

  resources :partials, only: :show

  namespace :injector do
    resources :users
    resources :directories do
      collection do
        post "move_graph"
        post "move_document"
      end
    end

    resources :documents do
      collection do
        post "publish_all"
      end
    end

    resources :groups
    resources :roles
    resource :link_updater, controller: "link_updater" do
      member do
        post "update_graph_links"
        post "update_doc_links"
      end
    end

    resource :repository, controller: "repository" do
      member do
        post "clear"
      end
    end

    resources :distribute, controller: "distribute"
  end

  namespace :improver do
    # Gestion des prints improver
    get "print_preferences" => "print#preferences", :as => "print_preferences"
    post "print" => "print#print", :as => "print"

    concern :filterable do
      collection do
        get "clear_filter"
      end
    end

    scope :search, controller: :search do
      get "events", as: :search_event
      get "acts", as: :search_act
      get "audits", as: :search_audit
      get "groups", as: :search_group
      get "users", as: :search_user
    end

    namespace :settings do
      resource :reference, only: %i[edit update]
      resource :globals do
        put "update_user"
      end
    end

    resources :indicators do
      collection do
        get "events"
        get "acts"
        get "closed_events"
        get "closed_acts"
        get "event_types"
        get "act_types"
        get "events_criticality"
        get "acts_verif_types"
        get "monthly_created_events"
        get "monthly_closed_events"
        get "monthly_created_acts"
        get "monthly_closed_acts"
        get "event_causes"
        get "acts_eval_types"
        get "acts_efficiencies"
      end
    end

    resources :attachments, only: :create
  end

  namespace :store do
    root controller: :dashboard, action: :index

    resources :packages do
      member do
        get "import"
        post "confirm_import"
        get "delete"
        get "new_version"
      end
    end

    resources :connections, only: :index do
      member do
        get :respond_invitation
      end
    end

    resources :design do
      collection do
        get "import"
        get "import_two"
        get "import_three"
        get "import_final"
        get "list"
        get "tiles"
        get "settings"
        get "dashboard"
        get "new_one"
        get "new_two"
        get "new_three"
        get "view"
      end
    end
  end

  namespace :api do
    resources :package_graphs, only: :elements do
      member do
        get :elements
      end
    end
    resources :graphs do
      collection do
        get :search
      end
      member do
        get :dependencies
      end
    end
    resources :packages do
      collection do
        get :search
      end
      member do
        get :customer_logo
      end
    end

    resources :connections, only: [] do
      collection do
        put :toggle_video
      end
      member do
        post "", action: :request_connection, as: :request
        put :accept
        put :reject
        delete "", action: :disconnect, as: :disconnect
      end
    end

    resources :subscriptions, only: [] do
      collection do
        post :prepend
      end
      member do
        put :toggle
        delete "", action: :remove, as: :remove
      end
    end

    resources :logo, only: [] do
      collection do
        get "customer/:id", action: :customer, as: :customer
      end
    end

    resources :tags, only: [] do
      collection do
        get "suggest"
      end
    end

    # api/process_documents/search.json
    resource :process_documents, only: [] do
      get "/search", to: "search#applicable_graph_doc"
    end

    namespace :search do
      get "applicable_graph_doc"
    end
  end

  authenticated :super_admin do
    mount Sidekiq::Web => "/sidekiq"
  end

  #
  # These routes will generate proper path helpers to Improver routes.
  #
  # @note These routes are tightly coupled with React routes defined for each
  #   application module and sub-modules.
  #
  scope :improver, as: :improver, to: "spa#index" do
    %w[actions audits events].each do |sub_module|
      resources sub_module, only: %i[index show]
    end

    get "events/declare_popup"

    scope :settings, as: :settings do
      %w[actions actors audits events].each do |settings_module|
        resources settings_module, only: %i[index]
      end
    end
  end

  #
  # These routes will generate proper path helpers to Risk module routes.
  #
  # @note These routes are tightly coupled with React routes defined for each
  #   application module and sub-modules.
  #
  scope :risks, as: :risks, to: "spa#index" do
    resources "risks", only: %i[index show]

    get "risks/declare_popup"

    scope :settings, as: :settings do
      %w[actors risks scales].each do |settings_module|
        resources settings_module, only: %i[index]
      end
    end
  end

  # Catch all for each SPA application module
  %i[improver risks].each do |spa_module|
    get spa_module, to: "spa#index"
    get "#{spa_module}/*all", to: "spa#index"
  end

  # Catch all for SPA modules still in development
  if Rails.env.development?
    %i[users].each do |spa_module|
      get spa_module, to: "spa#index"
      get "#{spa_module}/*all", to: "spa#index"
    end
  end
end
