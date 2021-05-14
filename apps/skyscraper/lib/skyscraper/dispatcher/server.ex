defmodule Skyscraper.Dispatcher.Server do
  alias Skyscraper.Elevator.Server, as: Elevator
  alias Skyscraper.{Dispatcher, Interface}
  require IEx
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :building) |> name())
  end

  def push_button(id, button) do
    id
    |> name()
    |> GenServer.cast({:push_button, button})
  end

  def set_time_to_destination(id, el_id, dest_info) do
    id
    |> name()
    |> GenServer.call({:set_time_to_destination, el_id, dest_info})
  end

  def notify_destination_reached(id, el_id, destination) do
    id
    |> name()
    |> GenServer.cast({:request_handled, el_id, destination})
  end

  def notify_new_destination(id, elevator_id) do
    id
    |> name()
    |> GenServer.cast({:elevator_changed_destination, elevator_id})
  end

  def init(args) do
    {:ok,
     %{
       building: Keyword.fetch!(args, :building),
       interface_mods: Keyword.fetch!(args, :interface_mods),
       dispatcher: Dispatcher.build(args)
     }}
  end

  def handle_cast({:push_button, button}, state) do
    # TODO: refactor to macros, since we should ask if button active and processible, before ask elevators about handle time
    state =
      if Dispatcher.button_active?(state.dispatcher, button) do
        state
      else
        state.dispatcher
        |> Dispatcher.push_button(
          button,
          elevators_handle_time(state.building, state.dispatcher, button)
        )
        |> process_new_state(state)
        |> display()
      end

    {:noreply, state}
  end

  def handle_cast({:elevator_changed_destination, el_id}, state) do
    state =
      state.dispatcher
      |> Dispatcher.propose_requests(el_id)
      |> process_new_state(state)

    {:noreply, state}
  end

  def handle_cast({:request_handled, el_id, destination}, state) do
    state =
      state
      |> Map.put(:dispatcher, state.dispatcher |> Dispatcher.request_handled(el_id, destination))
      |> display()

    {:noreply, state}
  end

  def handle_call({:set_time_to_destination, el_id, dest_info}, _caller, state) do
    state =
      state.dispatcher
      |> Dispatcher.set_time_to_destination(el_id, dest_info)
      |> process_new_state(state)

    {:reply, :ok, state}
  end

  defp elevators_handle_time(building, dispatcher, button) do
    # IEx.pry()

    dispatcher
    |> Dispatcher.elevator_ids()
    |> Enum.map(fn el_id ->
      {el_id,
       Task.Supervisor.async(Skyscraper.TaskSupervisor, fn ->
         Elevator.get_handle_time(building, el_id, button)
       end)}
    end)
    |> Enum.map(&{&1 |> elem(0), &1 |> elem(1) |> Task.await()})
  end

  defp name(id) do
    {:via, Registry, {Skyscraper.Registry, {__MODULE__, id}}}
  end

  defp process_new_state({instructions, dispatcher}, state) do
    Enum.reduce(instructions, dispatcher, &run_instruction(&1, &2, state))

    %{state | dispatcher: dispatcher}
  end

  defp run_instruction({:propose_to_handle, el_id, buttons}, dispatcher, state) do
    :ok = state.building |> Elevator.propose(el_id, buttons)
    dispatcher
  end

  defp run_instruction({:cancel_request, el_id, dest}, dispatcher, state) do
    :ok = state.building |> Elevator.cancel_request(el_id, dest)
    dispatcher
  end

  defp display(state) do
    # IEx.pry()

    Enum.each(state.interface_mods, fn interface_mod ->
      Task.Supervisor.start_child(Skyscraper.TaskSupervisor, fn ->
        Interface.change_dispatcher_state(
          interface_mod,
          state.building,
          state.dispatcher
        )
      end)
    end)

    state
  end
end
