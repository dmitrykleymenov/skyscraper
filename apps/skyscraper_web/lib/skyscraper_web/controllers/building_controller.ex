defmodule SkyscraperWeb.BuildingController do
  alias Skyscraper.Buildings
  use SkyscraperWeb, :controller

  def index(conn, _params) do
    building =
      Pow.Plug.current_user(conn)
      |> Buildings.fetch_building()

    render(conn, "edit.html", building: building)
  end
end
