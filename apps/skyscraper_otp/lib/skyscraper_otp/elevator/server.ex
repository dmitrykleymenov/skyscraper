defmodule SkyscraperOtp.Elevator.Server do
  use GenServer
  require IEx
  alias SkyscraperOtp.Dispatcher.Server, as: Dispatcher
  alias SkyscraperOtp.Elevator.Display
  alias SkyscraperOtp.{Elevator, Interface}

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: name_from_arg(arg))
  end

  @doc """
   Handles inside cabin button push
  """

  def push_button(building, id, button, registry \\ SkyscraperOtp.Registry) do
    name(building, id, registry)
    |> GenServer.cast({:push_elevator_button, button})
  end

  def get_handle_time(building, id, button, registry \\ SkyscraperOtp.Registry) do
    name(building, id, registry)
    |> GenServer.call({:get_handle_time, button})
  end

  def propose(building, id, buttons, registry \\ SkyscraperOtp.Registry) do
    name(building, id, registry)
    |> GenServer.cast({:propose, buttons})
  end

  def cancel_request(building, id, dest, registry \\ SkyscraperOtp.Registry) do
    name(building, id, registry)
    |> GenServer.cast({:cancel_request, dest})
  end

  def get_state(building, id, registry) do
    name(building, id, registry)
    |> GenServer.call({:get_state, building})
  end

  @impl GenServer
  def init(arg) do
    {:ok,
     %{
       elevator: Elevator.build(arg),
       building: Keyword.fetch!(arg, :building),
       id: Keyword.fetch!(arg, :id),
       interface_mods: Keyword.fetch!(arg, :interface_mods)
     }}
  end

  @impl GenServer
  def handle_cast({:push_elevator_button, button}, %{elevator: elevator} = state) do
    {:noreply, elevator |> Elevator.push_button(button) |> process_new_state(state) |> display()}
  end

  @impl GenServer
  def handle_cast({:propose, buttons}, %{elevator: elevator} = state) do
    {:noreply, elevator |> Elevator.propose(buttons) |> process_new_state(state)}
  end

  @impl GenServer
  def handle_cast({:cancel_request, dest}, %{elevator: elevator} = state) do
    {:noreply, elevator |> Elevator.cancel_request(dest) |> process_new_state(state)}
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

  @impl GenServer
  def handle_call({:get_state, building}, _caller, state) do
    {:reply, Display.build(building, state.id, state.elevator), state}
  end

  defp name(building, id, registry) do
    {:via, Registry, {registry, {__MODULE__, building, id}}}
  end

  defp name_from_arg(arg) do
    name(
      Keyword.fetch!(arg, :building),
      Keyword.fetch!(arg, :id),
      Keyword.get(arg, :registry, SkyscraperOtp.Registry)
    )
  end

  defp process_new_state({instructions, elevator}, state) do
    Enum.each(instructions, &run_instruction(&1, elevator, state))

    %{state | elevator: elevator}
  end

  defp run_instruction(:reserve_step_time, elevator, _state) do
    {:ok, _} = elevator |> Elevator.step_duration() |> :timer.send_after(:step_completed)
  end

  defp run_instruction({:send_time_for_destination, dest_info}, _elevator, state) do
    :ok = Dispatcher.set_time_to_destination(state.building, state.id, dest_info)
  end

  defp run_instruction(:notify_new_destination, _elevator, state) do
    :ok = Dispatcher.notify_new_destination(state.building, state.id)
  end

  defp run_instruction({:destination_reached, destination}, _elevator, state) do
    :ok = Dispatcher.notify_destination_reached(state.building, state.id, destination)
  end

  defp display(state) do
    Enum.each(state.interface_mods, fn interface_module ->
      Task.Supervisor.start_child(SkyscraperOtp.TaskSupervisor, fn ->
        Interface.change_elevator_state(
          interface_module,
          state.building,
          state.id,
          state.elevator
        )
      end)
    end)

    state
  end
end
