defmodule Skyscraper.Buildings do
  alias Skyscraper.Buildings.Building
  alias Skyscraper.Repo

  def change_building(user, attrs \\ %{}) do
    user
    |> Repo.preload(:building)
    |> user_building()
    |> Building.changeset(attrs)
  end

  def create_building(user, attrs) do
    user
    |> Building.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_building(user, attrs) do
    user
    |> change_building(attrs)
    |> Repo.update()
  end

  defp user_building(%{building: nil}), do: %Building{}
  defp user_building(user), do: user.building
end
