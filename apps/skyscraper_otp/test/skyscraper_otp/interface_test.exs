defmodule SkyscraperOtp.InterfaceTest do
  use ExUnit.Case, async: true
  alias SkyscraperOtp.Interface

  test "transfers the dispatcher display struct to interface implementation" do
    Interface.change_dispatcher_state(
      SkyscraperOtp.InterfaceTest.Echo,
      "some_building",
      SkyscraperOtp.Dispatcher.build(elevator_ids: [1, 2, 3], floors: 1..3)
    )

    receive do
      {:dispatcher, dispatcher} ->
        assert %SkyscraperOtp.Dispatcher.Display{} = dispatcher
    end
  end

  test "transfers the elevator display struct to interface implementation" do
    Interface.change_elevator_state(
      SkyscraperOtp.InterfaceTest.Echo,
      "some_building",
      "id",
      SkyscraperOtp.Elevator.build([]) |> elem(1)
    )

    receive do
      {:elevator, dispatcher} ->
        assert %SkyscraperOtp.Elevator.Display{} = dispatcher
    end
  end

  defmodule Echo do
    def elevator_state_changed(elevator) do
      send(self(), {:elevator, elevator})
    end

    def dispatcher_state_changed(dispatcher) do
      send(self(), {:dispatcher, dispatcher})
    end
  end
end
