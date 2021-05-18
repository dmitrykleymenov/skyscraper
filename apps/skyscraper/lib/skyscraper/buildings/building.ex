defmodule Skyscraper.Buildings.Building do
  alias __MODULE__
  use Ecto.Schema
  import Ecto.Changeset

  schema "buildings" do
    field(:name, :string)
    field(:floors_amount, :integer)
    field(:elevators_quantity, :integer)
    belongs_to :user, Skyscraper.Users.User

    timestamps()
  end

  @doc false
  def changeset(%Building{} = building, attrs) do
    building
    |> cast(attrs, [:name, :floors_amount, :elevators_quantity])
    |> validate_required([:name, :floors_amount, :elevators_quantity])
    |> validate_inclusion(:elevators_quantity, 2..5)
    |> validate_inclusion(:floors_amount, 30..50)
    |> unique_constraint(:name)
  end

  @doc false
  def create_changeset(user, attrs) do
    %Building{}
    |> changeset(attrs)
    |> put_assoc(:user, user)
  end
end
