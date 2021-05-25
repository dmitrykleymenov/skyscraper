defmodule SkyscraperOtp.Dispatcher.Server do
  alias SkyscraperOtp.Elevator.Server, as: Elevator
  alias SkyscraperOtp.{Dispatcher, Interface, Cache}
  alias SkyscraperOtp.Dispatcher.Display
  require IEx
  use GenServer

  @moduledoc """
   Provides statefull and OTP related abstraction for `Dispatcher` logic
  """

  @doc false
  def start_link(arg) do
    registry = Keyword.get(arg, :registry, SkyscraperOtp.Registry)

    GenServer.start_link(__MODULE__, arg, name: Keyword.fetch!(arg, :building) |> name(registry))
  end

  @doc """
    Tells dispatcher with given `id` about pushed  hall `button`
  """
  def push_button(id, button, registry \\ SkyscraperOtp.Registry) do
    id
    |> name(registry)
    |> GenServer.cast({:push_button, button})
  end

  @doc """
    Sets destination info to `dest_info` for elevator with `el_id` from building with `id`
  """
  def set_time_to_destination(id, el_id, dest_info, registry \\ SkyscraperOtp.Registry) do
    id
    |> name(registry)
    |> GenServer.call({:set_time_to_destination, el_id, dest_info})
  end

  @doc """
    Tells dispatcher that elevator with `el_id` from building with `id` reached the `destination`
  """
  def notify_destination_reached(id, el_id, destination, registry \\ SkyscraperOtp.Registry) do
    id
    |> name(registry)
    |> GenServer.cast({:request_handled, el_id, destination})
  end

  @doc """
    Tells dispatcher that elevator with `el_id` from building with `id` changes its destination
  """
  def notify_new_destination(id, elevator_id, registry \\ SkyscraperOtp.Registry) do
    id
    |> name(registry)
    |> GenServer.cast({:elevator_changed_destination, elevator_id})
  end

  @doc """
    Returns elevator ids for buillding with `id`
  """
  def get_elevator_ids(id, registry) do
    id
    |> name(registry)
    |> GenServer.call(:get_elevator_ids)
  end

  @doc """
    Returns current `Dispatcher` state
  """
  def get_state(id, registry) do
    id
    |> name(registry)
    |> GenServer.call(:get_state)
  end

  @impl true
  def init(args) do
    building = Keyword.fetch!(args, :building)

    {:ok,
     %{
       building: building,
       interface_mods: Keyword.fetch!(args, :interface_mods),
       dispatcher: Cache.get_dispatcher(building) || Dispatcher.build(args)
     }}
  end

  @impl true
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

  @impl true
  def handle_cast({:elevator_changed_destination, el_id}, state) do
    state =
      state.dispatcher
      |> Dispatcher.propose_requests(el_id)
      |> process_new_state(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:request_handled, el_id, destination}, state) do
    state =
      state
      |> Map.put(:dispatcher, state.dispatcher |> Dispatcher.request_handled(el_id, destination))
      |> display()

    {:noreply, state}
  end

  @impl true
  def handle_call({:set_time_to_destination, el_id, dest_info}, _caller, state) do
    state =
      state.dispatcher
      |> Dispatcher.set_time_to_destination(el_id, dest_info)
      |> process_new_state(state)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_elevator_ids, _caller, state) do
    {:reply, state.dispatcher |> Dispatcher.elevator_ids(), state}
  end

  @impl true
  def handle_call(:get_state, _caller, state) do
    {:reply, Display.build(state.building, state.dispatcher), state}
  end

  defp elevators_handle_time(building, dispatcher, button) do
    dispatcher
    |> Dispatcher.elevator_ids()
    |> Enum.map(fn el_id ->
      {el_id,
       Task.Supervisor.async(SkyscraperOtp.TaskSupervisor, fn ->
         Elevator.get_handle_time(building, el_id, button)
       end)}
    end)
    |> Enum.map(&{&1 |> elem(0), &1 |> elem(1) |> Task.await()})
  end

  defp name(id, registry) do
    {:via, Registry, {registry, {__MODULE__, id}}}
  end

  defp process_new_state({instructions, dispatcher}, state) do
    instructions |> Enum.each(&run_instruction(&1, state))
    Cache.update_dispatcher(state.building, dispatcher)

    %{state | dispatcher: dispatcher}
  end

  defp run_instruction({:propose_to_handle, el_id, buttons}, state) do
    :ok = state.building |> Elevator.propose(el_id, buttons)
  end

  defp run_instruction({:cancel_request, el_id, dest}, state) do
    :ok = state.building |> Elevator.cancel_request(el_id, dest)
  end

  defp display(state) do
    Enum.each(state.interface_mods, fn interface_mod ->
      Task.Supervisor.start_child(SkyscraperOtp.TaskSupervisor, fn ->
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
