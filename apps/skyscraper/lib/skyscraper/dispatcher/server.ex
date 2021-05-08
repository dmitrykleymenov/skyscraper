defmodule Skyscraper.Dispatcher.Server do
  alias Skyscraper.Elevator.Server, as: Elevator
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :dispatcher_id) |> name())
  end

  def notify_new_destination(id, elevator_id) do
    id
    |> name()
    |> GenServer.cast({:elevator_changed_destination, elevator_id})
  end

  def push_button(id, button) do
    id
    |> name()
    |> GenServer.cast({:push_button, button})
  end

  def init(args) do
    elevators = for el_id <- Keyword.fetch!(args, :elevator_ids), do: {el_id, nil}, into: %{}

    {:ok,
     %{
       id: Keyword.fetch!(args, :dispatcher_id),
       elevators: elevators,
       callback_mod: Keyword.fetch!(args, :callback_mod),
       queue: []
     }}
  end

  def handle_cast({:elevator_changed_destination, _elevator}, state) do
    {:noreply, state}
  end

  def handle_cast({:push_button, button}, %{building: building} = state) do
    # {instructions, state} = .push_button(state.building, button)

    # {:noreply, building |> Building.push_button(button) |> process_new_state(state) |> display()}

    # optimal_elevator =
    #   state.elevators
    #   |> Map.keys()
    #   |> Enum.map(fn el_id ->
    #     {el_id,
    #      Task.Supervisor.start_child(Skyscraper.TaskSupervisor, fn ->
    #        Elevator.get_handle_time(state.id, el_id, button)
    #      end)}
    #   end)
    #   |> Enum.map(&{elem(&1, 0), elem(&1, 1) |> Task.await()})
    #   |> Enum.filter(&elem(&1, 1))
    #   |> Enum.min_by(&elem(&1, 1), fn -> nil end)

    # state =
    #   state
    #   |> Map.put(:queue, [button | state.queue])
    #   |> Map.put(:elevators, appoint_executor(state.elevators, button, optimal_elevator))

    {:noreply, state}
  end

  defp appoint_executor(elevators, _button, nil), do: elevators

  defp appoint_executor(elevators, button, {el_id, handle_time}) do
    elevators
    |> Enum.find(fn {_id, {dest, _time}} -> dest == button end)
    |> elem(0)
    |> cancel_request(button)
  end

  defp cancel_request(el_id, button) do
    Elevator.cancel_request()
  end

  defp name(id) do
    {:via, Registry, {Skyscraper.Registry, {__MODULE__, id}}}
  end
end
