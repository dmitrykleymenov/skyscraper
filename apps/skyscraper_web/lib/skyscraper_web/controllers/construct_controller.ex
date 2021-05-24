defmodule SkyscraperWeb.ConstructController do
  use SkyscraperWeb, :controller

  def create(conn, user) do
    unless SkyscraperOtp.active?(user.building.name) do
      SkyscraperOtp.build(
        building: user.building.name,
        floors_amount: user.building.floors_amount,
        elevators_quantity: user.building.elevators_quantity
      )
    end

    SkyscraperOtp.Cleaner.touch(building: user.building.name)

    redirect(conn, to: Routes.live_path(conn, SkyscraperWeb.ConstructLive, user.building.name))
  end

  def destroy(conn, user) do
    building = user.building.name

    if SkyscraperOtp.active?(building) do
      SkyscraperOtp.Cleaner.destroy(building)
      building |> SkyscraperOtp.Cache.clear_building()
    end

    redirect(conn, to: Routes.page_path(conn, :index))
  end

  def action(conn, _) do
    args = [conn, conn.assigns.current_user]
    apply(__MODULE__, action_name(conn), args)
  end
end
