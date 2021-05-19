defmodule SkyscraperWeb.ConstructController do
  use SkyscraperWeb, :controller

  def create(conn, user) do
    building = Skyscraper.Repo.preload(user, :building).building

    # SkyscraperOtp.build(building: "moscow tower", floors_amount: 50, elevators_quantity: 3)

    SkyscraperOtp.build(
      building: building.name,
      floors_amount: building.floors_amount,
      elevators_quantity: building.elevators_quantity
    )

    redirect conn, to: Routes.construct_path(conn, :show, id: building.id)

    # case user |> Buildings.create_building(building_params) do
    #   {:ok, _building} ->
    #     conn
    #     |> put_flash(:info, "Building is created.")
    #     |> redirect(to: Routes.building_path(conn, :edit))

    #   {:error, %Ecto.Changeset{} = changeset} ->
    #     render(conn, "edit.html", changeset: changeset)
    # end
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
    args = [conn, Pow.Plug.current_user(conn)]
    apply(__MODULE__, action_name(conn), args)
  end
end
