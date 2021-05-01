defmodule Skyscraper.Elevator do
  use GenServer
  require IEx
  alias Skyscraper.Elevator.Car
  alias Skyscraper.{Dispatcher, Display}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: name_from_opts(opts))
  end

  @doc """
   Handles inside cabin button push
  """
  def push_button(dispatcher_id, elevator_id, floor) do
    GenServer.cast(name(dispatcher_id, elevator_id), {:push_car_button, floor})
  end

  @impl GenServer
  def init(opts) do
    car = Car.build(opts)

    {:ok,
     %{
       car: car,
       dispatcher: Keyword.fetch!(opts, :dispatcher),
       id: Keyword.fetch!(opts, :id),
       callback_mod: Keyword.fetch!(opts, :callback_mod)
     }}
  end

  @impl GenServer
  def handle_cast({:push_car_button, floor}, %{car: car} = state) do
    {:noreply, car |> Car.push_button(floor) |> process_state(state) |> display()}
  end

  @impl GenServer
  def handle_info(:step_completed, %{car: car} = state) do
    {:noreply, car |> Car.complete_step() |> process_state(state) |> display()}
  end

  def name(dispatcher, id) do
    {:via, Registry, {Skyscraper.Registry, {__MODULE__, dispatcher, id}}}
  end

  defp name_from_opts(opts) do
    name(Keyword.fetch!(opts, :dispatcher), Keyword.fetch!(opts, :id))
  end

  defp process_state({instructions, car}, state) do
    Enum.each(instructions, &handle_instruction(&1, car, state))

    %{state | car: car}
  end

  defp handle_instruction(:reserve_step_time, car, _state) do
    {:ok, _} = car |> Car.step_duration() |> :timer.send_after(:step_completed)
  end

  defp handle_instruction(:notify_new_destination, _car, state) do
    Dispatcher.notify_new_destination(state.dispatcher, state.id)
  end

  defp display(state) do
    Task.Supervisor.start_child(Skyscraper.TaskSupervisor, fn ->
      Display.change_elevator_state(state.callback_mod, state.dispatcher, state.id, state.car)
    end)

    state
  end
end
