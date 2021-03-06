defmodule SkyscraperWeb.Router do
  use SkyscraperWeb, :router

  use Pow.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {SkyscraperWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :set_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :protected do
    plug(Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
    )
  end

  scope "/" do
    pipe_through :browser

    pow_routes()
  end

  scope "/", SkyscraperWeb do
    pipe_through :browser

    live "/", PageLive, :index
    live "/construct/:id", ConstructLive
  end

  scope "/", SkyscraperWeb do
    pipe_through([:browser, :protected])

    get("/building", BuildingController, :edit)
    post("/building", BuildingController, :create)
    put("/building", BuildingController, :update)

    post("/construct", ConstructController, :create)
    delete("/construct", ConstructController, :destroy)
  end

  # Other scopes may use custom stacks.
  # scope "/api", SkyscraperWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: SkyscraperWeb.Telemetry
    end
  end

  def set_current_user(conn, _params) do
    case Pow.Plug.current_user(conn) do
      nil -> conn
      user -> conn |> assign(:current_user, user |> Skyscraper.Repo.preload(:building))
    end
  end
end
