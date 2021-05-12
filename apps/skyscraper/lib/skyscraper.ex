defmodule Skyscraper do
  alias Skyscraper.Elevator.Server, as: Elevator
  alias Skyscraper.Dispatcher.Server, as: Dispatcher
  alias Skyscraper.Interface.Console
  alias Skyscraper.{BuildingsSupervisor, BuildingSupervisor}

  @moduledoc """
  Skyscraper keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def build(arg) do
    name = Keyword.fetch!(arg, :name)

    args = [
      building: name,
      floors: Keyword.fetch!(arg, :floors_amount) |> floors(),
      elevator_ids: Keyword.fetch!(arg, :elevators_quantity) |> elevator_ids(),
      interface_mods: Keyword.get(arg, :interface_mods, [Console])
    ]

    DynamicSupervisor.start_child(
      BuildingsSupervisor,
      Supervisor.child_spec({BuildingSupervisor, args}, id: name)
    )
  end

  def push_elevator_button(building, elevator_id, floor) do
    Elevator.push_button(building, elevator_id, floor)
  end

  def push_hall_button(building, button) do
    Dispatcher.push_button(building, button)
  end

  defp floors(floors_amount) do
    1..floors_amount |> Enum.to_list()
  end

  defp elevator_ids(elevators_quantity) do
    Stream.iterate(1, &(&1 + 1)) |> Enum.take(elevators_quantity)
  end
end
