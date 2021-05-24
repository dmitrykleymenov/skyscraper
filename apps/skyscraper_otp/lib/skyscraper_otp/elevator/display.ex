defmodule SkyscraperOtp.Elevator.Display do
  alias __MODULE__
  alias SkyscraperOtp.Elevator
  defstruct [:building, :id, :status, :current_floor, :floor_buttons]

  @moduledoc """
    Module defines `Elevator` struct which is provided to `Interface` behaviour
  """

  @doc """
    Builds a `Display` struct for `elevator` with `id` from `buiding`
  """
  def build(building, id, elevator) do
    %Display{
      building: building,
      id: id,
      status: elevator |> Elevator.step(),
      current_floor: elevator |> Elevator.current_floor(),
      floor_buttons: elevator |> floor_buttons()
    }
  end

  defp floor_buttons(elevator) do
    floors_to_handle = Elevator.floors_to_handle(elevator)
    for floor <- Elevator.acceptable_floors(elevator), do: {floor, floor in floors_to_handle}
  end
end
