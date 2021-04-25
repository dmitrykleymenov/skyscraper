defmodule Skyscraper.Elevator do
  use GenServer
  require IEx
  alias Skyscraper.Elevator.Car

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def push_car_button(elevator, floor) do
    GenServer.cast(elevator, {:push_car_button, floor})
  end

  def init(opts) do
    car =
      Car.build(
        floor: Keyword.get(opts, :floor, 1),
        new_destination_callback: &notify_new_destination(&1, Keyword.get(opts, :dispatcher)),
        processing_callback: &reserve_time(&1)
      )

    {:ok, car}
  end

  def handle_cast({:push_car_button, floor}, car) do
    {:noreply, car |> Car.push_button(floor)}
  end

  def handle_info(:step_completed, car) do
    {:noreply, car |> Car.complete_step()}
  end

  defp reserve_time(car) do
    {:ok, _} = car |> Car.step_duration() |> :timer.send_after(:step_completed)
  end

  defp notify_new_destination(_car, dispatcher) do
    # IEx.pry()
    GenServer.cast(dispatcher, {:ready_to_new_destination, self()})
  end
end
