defmodule Skyscraper.Repo.Migrations.CreateBuildings do
  use Ecto.Migration

  def change do
    create table(:buildings) do
      add :name, :string, null: false
      add :floors_amount, :integer
      add :elevators_quantity, :integer
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:buildings, [:name])
  end
end
