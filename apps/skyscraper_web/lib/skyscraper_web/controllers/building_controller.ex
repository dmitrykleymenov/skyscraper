defmodule SkyscraperWeb.BuildingController do
  alias Skyscraper.Buildings
  use SkyscraperWeb, :controller

  def edit(conn, _params, user) do
    changeset = user |> Buildings.change_building()
    render(conn, "edit.html", changeset: changeset)
  end

  def create(conn, %{"building" => building_params}, user) do
    case user |> Buildings.create_building(building_params) do
      {:ok, _building} ->
        conn
        |> put_flash(:info, "Building is created.")
        |> redirect(to: Routes.building_path(conn, :edit))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def update(conn, %{"building" => building_params}, user) do
    case user |> Buildings.update_building(building_params) do
      {:ok, _building} ->
        conn
        |> put_flash(:info, "Building is updated successfully.")
        |> redirect(to: Routes.building_path(conn, :edit))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def action(conn, _) do
    args = [conn, conn.params, conn.assigns.current_user]
    apply(__MODULE__, action_name(conn), args)
  end
end
