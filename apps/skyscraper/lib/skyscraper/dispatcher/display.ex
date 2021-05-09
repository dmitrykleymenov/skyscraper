defmodule Skyscraper.Dispatcher.Display do
  alias __MODULE__
  alias Skyscraper.Dispatcher
  defstruct [:building, :elevator_id, :status, :current_floor, :floor_buttons]

  def build(dispatcher, id, car) do
    %Display{
      building: dispatcher,
      elevator_id: id,
      status: car |> Car.step(),
      current_floor: car |> Car.current_floor(),
      floor_buttons: car |> floor_buttons()
    }
  end

  defp floor_buttons(car) do
    floors_to_handle = Car.floors_to_handle(car)
    for floor <- Car.acceptable_floors(car), do: {floor, floor in floors_to_handle}
  end
end
