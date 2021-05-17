defmodule SkyscraperWeb.BuildingController do
  alias Skyscraper.Buildings
  use SkyscraperWeb, :controller

  def edit(conn, _params, user) do
    changeset = user |> Buildings.change_building()
    render(conn, "edit.html", changeset: changeset)
  end

  def update(conn, %{"building" => building_params}, user) do
    case user |> Buildings.update_building(building_params) do
      {:ok, _building} ->
        conn
        |> put_flash(:info, "Building is updated successfully.")
        |> redirect(to: Routes.building_path(conn, :update))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def action(conn, _) do
    args = [conn, conn.params, Pow.Plug.current_user(conn)]
    apply(__MODULE__, action_name(conn), args)
  end
end
