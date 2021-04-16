defmodule Skyscraper.Elevator do
  use GenServer
  alias Skyscraper.Elevator.Car

  @step_time 1000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def push_car_button(elevator, floor) do
    GenServer.cast(elevator, {:push_car_button, floor})
  end

  def init(opts) do
    current_floor = Keyword.get(opts, :current_floor, 1)
    {:ok, car: %Car{current_floor: current_floor}}
  end

  def handle_cast({:push_car_button, floor}, %{car: car, timer: timer}) do
    {:noreply, %{car: Car.push_button(car, floor), timer: timer || start_timer()}}
  end

  def handle_info(:process, %{car: car}) do
    case Car.process(car) do
      {:processing, car} -> {:noreply, %{car: car, timer: start_timer()}}
      {:idle, car} -> {:noreply, %{car: car, timer: nil}}
    end
  end

  defp start_timer do
    {:ok, timer} = :timer.send_after(@step_time, :process)
  end
end
