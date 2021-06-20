defmodule SkyscraperWeb.ConstructController do
  use SkyscraperWeb, :controller
  alias SkyscraperOtp.Cleaner.Server, as: Cleaner
  @max_idle_seconds_on_create 15 * 60

  def create(conn, user) do
    unless SkyscraperOtp.active?(user.building.name) do
      SkyscraperOtp.build(
        building: user.building.name,
        floors_amount: user.building.floors_amount,
        elevators_quantity: user.building.elevators_quantity
      )
    end

    Cleaner.touch(user.building.name, max_idle_seconds: @max_idle_seconds_on_create)

    redirect(conn, to: Routes.live_path(conn, SkyscraperWeb.ConstructLive, user.building.name))
  end

  def destroy(conn, user) do
    building = user.building.name

    if SkyscraperOtp.active?(building) do
      building |> Cleaner.destroy()
      building |> SkyscraperOtp.Cache.clear_building()
    end

    redirect(conn, to: Routes.page_path(conn, :index))
  end

  def action(conn, _) do
    args = [conn, conn.assigns.current_user]
    apply(__MODULE__, action_name(conn), args)
  end
end
