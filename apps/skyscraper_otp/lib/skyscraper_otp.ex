defmodule SkyscraperOtp do
  alias SkyscraperOtp.Elevator.Server, as: Elevator
  alias SkyscraperOtp.Dispatcher.Server, as: Dispatcher
  alias SkyscraperOtp.Interface.Console
  alias SkyscraperOtp.{BuildingsSupervisor, BuildingSupervisor}

  @moduledoc """
  SkyscraperOtp keeps whole OTP related logic for elevators and dispatcher
  """

  def build(arg) do
    args = [
      building: Keyword.fetch!(arg, :building),
      floors: Keyword.fetch!(arg, :floors_amount) |> floors(),
      elevator_ids: Keyword.fetch!(arg, :elevators_quantity) |> elevator_ids(),
      interface_mods: Keyword.get(arg, :interface_mods, [Console])
    ]

    DynamicSupervisor.start_child(BuildingsSupervisor, {BuildingSupervisor, args})
  end

  def destroy(building, registry \\ SkyscraperOtp.Registry) do
    [{pid, _}] = Registry.lookup(registry, BuildingSupervisor.registry_key(building))

    DynamicSupervisor.terminate_child(BuildingsSupervisor, pid)
  end

  def get_state(building, registry \\ SkyscraperOtp.Registry) do
    dispatcher_state = building |> Dispatcher.get_state(registry)

    elevator_states =
      building
      |> Dispatcher.get_elevator_ids(registry)
      |> Enum.map(fn el_id -> Elevator.get_state(building, el_id, registry) end)

    %{
      dispatcher: dispatcher_state,
      elevators: elevator_states
    }
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
