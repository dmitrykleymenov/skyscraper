defmodule Skyscraper.Buildings do
  alias Skyscraper.Buildings.Building

  def fetch_building(user) do
    Skyscraper.Repo.preload(user, :building).building || %Building{}
  end
end
