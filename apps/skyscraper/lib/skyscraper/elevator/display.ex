defmodule Skyscraper.Elevator.Display do
  alias __MODULE__
  alias Skyscraper.Elevator
  defstruct [:building, :elevator_id, :status, :current_floor, :floor_buttons]

  def build(building, id, car) do
    %Display{
      building: building,
      elevator_id: id,
      status: car |> Elevator.step(),
      current_floor: car |> Elevator.current_floor(),
      floor_buttons: car |> floor_buttons()
    }
  end

  defp floor_buttons(car) do
    floors_to_handle = Elevator.floors_to_handle(car)
    for floor <- Elevator.acceptable_floors(car), do: {floor, floor in floors_to_handle}
  end
end
