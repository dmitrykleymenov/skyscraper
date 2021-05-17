defmodule Skyscraper.Buildings do
  alias Skyscraper.Buildings.Building
  alias Skyscraper.Repo

  def change_building(user) do
    user
    |> user_building()
    |> Building.changeset(%{})
  end

  def update_building(user, attrs) do
    user
    |> user_building()
    |> Building.changeset(attrs)
    |> Repo.update()
  end

  defp user_building(user) do
    Repo.preload(user, :building).building || %Building{}
  end
end
