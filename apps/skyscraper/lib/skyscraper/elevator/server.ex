defmodule Skyscraper.Elevator.Server do
  use GenServer
  require IEx
  alias Skyscraper.Dispatcher.Server, as: Dispatcher
  alias Skyscraper.{Elevator, Interface}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: name_from_opts(opts))
  end

  @doc """
   Handles inside cabin button push
  """
  def push_button(dispatcher_id, elevator_id, floor) do
    GenServer.cast(name(dispatcher_id, elevator_id), {:push_elevator_button, floor})
  end

  def get_handle_time(dispatcher_id, elevator_id, floor) do
    GenServer.call(name(dispatcher_id, elevator_id), {:get_handle_time, floor})
  end

  @impl GenServer
  def init(opts) do
    elevator = Elevator.build(opts)

    {:ok,
     %{
       elevator: elevator,
       building: Keyword.fetch!(opts, :building),
       id: Keyword.fetch!(opts, :id),
       interface_mod: Keyword.fetch!(opts, :interface_mod)
     }}
  end

  @impl GenServer
  def handle_cast({:push_elevator_button, floor}, %{elevator: elevator} = state) do
    {:noreply, elevator |> Elevator.push_button(floor) |> process_new_state(state) |> display()}
  end

  @impl GenServer
  def handle_info(:step_completed, %{elevator: elevator} = state) do
    {:noreply, elevator |> Elevator.complete_step() |> process_new_state(state) |> display()}
  end

  @impl GenServer
  def handle_call({:get_handle_time, button}, _caller, %{elevator: elevator} = state) do
    reply =
      if Elevator.can_handle?(elevator, button),
        do: Elevator.additional_handling_time(elevator, button)

    {:reply, reply, state}
  end

  def name(building, id) do
    {:via, Registry, {Skyscraper.Registry, {__MODULE__, building, id}}}
  end

  defp name_from_opts(opts) do
    name(Keyword.fetch!(opts, :building), Keyword.fetch!(opts, :id))
  end

  defp process_new_state({instructions, elevator}, state) do
    Enum.each(instructions, &run_instruction(&1, elevator, state))

    %{state | elevator: elevator}
  end

  defp run_instruction(:reserve_step_time, elevator, _state) do
    {:ok, _} = elevator |> Elevator.step_duration() |> :timer.send_after(:step_completed)
  end

  defp run_instruction(:notify_new_destination, _elevator, state) do
    :ok = Dispatcher.notify_new_destination(state.building, state.id)
  end

  defp display(state) do
    Task.Supervisor.start_child(Skyscraper.TaskSupervisor, fn ->
      Interface.change_elevator_state(
        state.interface_mod,
        state.building,
        state.id,
        state.elevator
      )
    end)

    state
  end
end