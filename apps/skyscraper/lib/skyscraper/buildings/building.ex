defmodule Skyscraper.Buildings.Building do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  schema "buildings" do
    field(:name, :string)
    field(:floors_amount, :integer)
    field(:elevators_quantity, :integer)
    belongs_to :user, Skyscraper.Users.User

    timestamps()
  end

  @doc false
  def changeset(building, attrs) do
    building
    |> cast(attrs, [:name, :floors_amount, :elevators_quantity])
    |> validate_required([:name, :floors_amount, :elevators_quantity])
    |> unique_constraint(:name)
  end
end
