defmodule Skyscraper.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema
  alias Skyscraper.Buildings.Building

  schema "users" do
    pow_user_fields()
    has_one :building, Building

    timestamps()
  end
end
