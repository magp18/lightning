defmodule LightningWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use LightningWeb, :controller
      use LightningWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      # , helpers: false
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: LightningWeb.Layouts]

      import Plug.Conn
      import LightningWeb.Gettext
      import LightningWeb.UserAuth, only: [fetch_current_user: 2]
      alias LightningWeb.Router.Helpers, as: Routes

      unquote(verified_routes())
    end
  end

  # This is deprecated, once the mailers have been moved to Layouts, remove this
  def view do
    quote do
      use Phoenix.View,
        root: "lib/lightning_web/templates",
        namespace: LightningWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(html_helpers())
    end
  end

  def live_view(opts \\ []) do
    quote do
      @opts Keyword.merge(
              [layout: {LightningWeb.Layouts, :live}],
              unquote(opts)
            )
      use Phoenix.LiveView, @opts

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def component do
    quote do
      use Phoenix.Component

      unquote(html_helpers())
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import LightningWeb.Gettext
    end
  end

  defp html_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import LiveView and .heex helpers (live_render, live_patch, <.form>, etc)
      use Phoenix.Component
      import LightningWeb.LiveHelpers
      import LightningWeb.CoreComponents
      alias LightningWeb.LayoutComponents

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import LightningWeb.ErrorHelpers
      import LightningWeb.FormHelpers
      import LightningWeb.Gettext
      alias LightningWeb.Router.Helpers, as: Routes

      import PetalComponents.Avatar
      import PetalComponents.Card
      import PetalComponents.Dropdown
      import PetalComponents.Table
      import PetalComponents.Typography
      import PetalComponents.Badge
      import PetalComponents.Tabs

      alias LightningWeb.Components
      alias Components.Layout
      alias Components.Settings
      alias Components.Common
      alias Components.Icon

      unquote(verified_routes())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: LightningWeb.Endpoint,
        router: LightningWeb.Router,
        statics: LightningWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__({which, opts}) when is_atom(which) do
    apply(__MODULE__, which, [opts])
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end