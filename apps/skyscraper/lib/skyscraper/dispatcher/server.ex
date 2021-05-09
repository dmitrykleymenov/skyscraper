defmodule Skyscraper.Dispatcher.Server do
  alias Skyscraper.Elevator.Server, as: Elevator
  alias Skyscraper.{Dispatcher, Interface}
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :building) |> name())
  end

  def push_button(id, button) do
    id
    |> name()
    |> GenServer.cast({:push_button, button})
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

  def handle_cast({:push_button, button}, %{dispatcher: disp} = state) do
    disp = disp |> Dispatcher.push_button(button) |> process_new_state(state) |> display()

    {:noreply, %{state | dispather: disp}}
  end

  def handle_cast({:elevator_changed_destination, _elevator}, state) do
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

  defp process_new_state({instructions, dispatcher}, state) do
    Enum.each(instructions, &run_instruction(&1, dispatcher, state))

    %{state | dispatcher: dispatcher}
  end

  defp run_instruction(:reserve_step_time, dispatcher, _state) do
    # {:ok, _} = elevator |> Elevator.step_duration() |> :timer.send_after(:step_completed)
  end

  # defp run_instruction(:notify_new_destination, _elevator, state) do
  #   :ok = Dispatcher.notify_new_destination(state.dispatcher, state.id)
  # end

  defp display(state) do
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
