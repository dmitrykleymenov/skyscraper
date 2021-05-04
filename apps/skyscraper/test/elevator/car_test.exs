defmodule Skyscraper.Elevator.CarTest do
  alias Skyscraper.Elevator.{Car, Queue}
  use ExUnit.Case, async: true
  doctest Car

  test "builds a Car struct with the given params" do
    car = Car.build(current_floor: 5, floors: [4, 5, 6])
    assert %Car{} = car
    assert car.current_floor == 5
    assert car.acceptable_floors == [4, 5, 6]
    assert car.step == :idling
    assert %Queue{} = car.queue
  end

  test "returns all floors to handle" do
    assert build_car() |> Car.floors_to_handle() == []

    car =
      build_car(
        destination: {5, :up},
        queue: Queue.build() |> Queue.push({6, :up}) |> Queue.push({4, :down})
      )

    assert car |> Car.floors_to_handle() |> Enum.sort() == [4, 5, 6]
  end

  test "returns current floor" do
    assert Car.build() |> Car.current_floor() == 1
    assert Car.build(current_floor: 5) |> Car.current_floor() == 5
  end

  describe "#push_button" do
    test "when idling and is on the destination floor opens the doors and gives start instuctions" do
      car = build_car(current_floor: 6)
      assert car |> Car.step() == :idling
      assert car |> Car.current_floor() == 6
      assert car |> Car.floors_to_handle() |> Enum.empty?()

      {instructions, car} = car |> Car.push_button(6)
      assert car |> Car.step() == :opening_doors
      assert car |> Car.floors_to_handle() |> Enum.empty?()

      assert instructions == [:reserve_step_time]
    end

    test "when idling and isn't on the destination floor starts moving and gives start instructions" do
      car = build_car()
      assert car |> Car.step() == :idling
      assert car |> Car.current_floor() == 1
      assert car |> Car.floors_to_handle() |> Enum.empty?()

      {instructions, car} = car |> Car.push_button(6)
      assert car |> Car.step() == :moving_up
      assert 6 in Car.floors_to_handle(car)
      assert instructions == [:reserve_step_time]
    end

    test "when new floor request is destination floor and car isn't idling ignores the command" do
      car = build_car(destination: {6, :up}, step: :moving_up)
      {instructions, new_car} = car |> Car.push_button(6)

      assert car == new_car
      assert instructions |> Enum.empty?()
    end

    test "when new floor request is current floor and car is opening doors ignores the command" do
      car = build_car(current_floor: 6, step: :opening_doors)
      {instructions, new_car} = car |> Car.push_button(6)

      assert car == new_car
      assert instructions |> Enum.empty?()
    end

    test "when destination is nil puts new destination" do
      car = build_car(current_floor: 5, step: :closing_doors)
      assert Car.floors_to_handle(car) == []
      {instructions, car} = car |> Car.push_button(6)

      assert 6 in Car.floors_to_handle(car)
      assert car |> Car.step() == :closing_doors
      assert instructions |> Enum.empty?()
    end

    test "when moving and request is the current floor puts request to queue" do
      car = build_car(step: :moving_up, destination: {5, :up})
      assert car |> Car.current_floor() == 1
      assert car |> Car.floors_to_handle() == [5]
      {instructions, car} = car |> Car.push_button(1)

      assert car |> Car.floors_to_handle() == [5, 1]
      assert car |> Car.step() == :moving_up
      assert instructions |> Enum.empty?()
    end

    test "when request is between current floor and destination, changes the destination and puts the old one to queue" do
      car = build_car(step: :moving_up, destination: {5, :up})
      assert car |> Car.current_floor() == 1
      assert car |> Car.floors_to_handle() == [5]
      {instructions, car} = car |> Car.push_button(3)

      assert car |> Car.floors_to_handle() == [3, 5]
      assert car |> Car.step() == :moving_up
      assert instructions == [:notify_new_destination]
    end

    test "when request isn't between current floor and destination, puts it to queue" do
      car = build_car(step: :moving_up, destination: {5, :up})
      assert car |> Car.current_floor() == 1
      assert car |> Car.floors_to_handle() == [5]
      {instructions, car} = car |> Car.push_button(7)

      assert car |> Car.floors_to_handle() == [5, 7]
      assert car |> Car.step() == :moving_up
      assert instructions |> Enum.empty?()
    end
  end

  # @tag :skip
  # describe "#process" do
  #   test "opens the doors when they were started to open" do
  #     car = %Car{step: :doors_opening} |> Car.complete_step()
  #     assert car.step == :doors_opened
  #   end

  #   test "starts to close the doors when they were opened" do
  #     car = %Car{step: :doors_opened} |> Car.complete_step()
  #     assert car.step == :doors_closing
  #   end

  #   test "ups one floor and keeps moving up when destination isn't reached" do
  #     car =
  #       %Car{
  #         current_floor: 4,
  #         step: :moving,
  #         moving_direction: :up,
  #         upper_destinations: Prioqueue.new([6])
  #       }
  #       |> Car.complete_step()

  #     assert car.current_floor == 5
  #     assert car.step == :moving
  #     assert car.moving_direction == :up
  #   end

  #   test "ups one floor and starts to open doors when destination is reached by moving up" do
  #     car =
  #       %Car{
  #         current_floor: 4,
  #         step: :moving,
  #         moving_direction: :up,
  #         upper_destinations: Prioqueue.new([5])
  #       }
  #       |> Car.complete_step()

  #     assert car.current_floor == 5
  #     assert car.step == :doors_opening
  #     assert car.upper_destinations |> Prioqueue.to_list() == []
  #   end

  #   test "downs one floor and keeps moving down when destination isn't reached" do
  #     car =
  #       %Car{
  #         current_floor: 4,
  #         step: :moving,
  #         moving_direction: :down,
  #         lower_destinations: Prioqueue.new([2])
  #       }
  #       |> Car.complete_step()

  #     assert car.current_floor == 3
  #     assert car.step == :moving
  #   end

  #   test "downs one floor and starts to open doors when destination is reached by moving down" do
  #     car =
  #       %Car{
  #         current_floor: 4,
  #         step: :moving,
  #         moving_direction: :down,
  #         lower_destinations: Prioqueue.new([3])
  #       }
  #       |> Car.complete_step()

  #     assert car.current_floor == 3
  #     assert car.step == :doors_opening
  #     assert car.lower_destinations |> Prioqueue.to_list() == []
  #   end

  #   test "becomes idle when there are no more destinations on closing doors" do
  #     car =
  #       %Car{
  #         step: :doors_closing,
  #         lower_destinations: Prioqueue.new(),
  #         upper_destinations: Prioqueue.new()
  #       }
  #       |> Car.complete_step()

  #     refute car.step
  #     refute car.moving_direction
  #   end

  #   test "starts to move up on closing doors when was moving up before stop and has upper destinations" do
  #     car =
  #       %Car{
  #         step: :doors_closing,
  #         moving_direction: :up,
  #         lower_destinations: Prioqueue.new([3]),
  #         upper_destinations: Prioqueue.new([5])
  #       }
  #       |> Car.complete_step()

  #     assert car.step == :moving
  #     assert car.moving_direction == :up
  #   end

  #   test "starts to move down on closing doors when was moving up before stop and doesn't have an upper destination, but has lower destinations" do
  #     car =
  #       %Car{
  #         step: :doors_closing,
  #         moving_direction: :up,
  #         lower_destinations: Prioqueue.new([5]),
  #         upper_destinations: Prioqueue.new()
  #       }
  #       |> Car.complete_step()

  #     assert car.step == :moving
  #     assert car.moving_direction == :down
  #   end

  #   test "starts to move down on closing doors when was moving down before stop and has lower destinations" do
  #     car =
  #       %Car{
  #         step: :doors_closing,
  #         moving_direction: :down,
  #         lower_destinations: Prioqueue.new([3]),
  #         upper_destinations: Prioqueue.new([5])
  #       }
  #       |> Car.complete_step()

  #     assert car.step == :moving
  #     assert car.moving_direction == :down
  #   end

  #   test "starts to move up on closing doors when was moving down before stop and doesn't have a lower destination, but has upper destinations" do
  #     car =
  #       %Car{
  #         step: :doors_closing,
  #         moving_direction: :down,
  #         lower_destinations: Prioqueue.new(),
  #         upper_destinations: Prioqueue.new([5])
  #       }
  #       |> Car.complete_step()

  #     assert car.step == :moving
  #     assert car.moving_direction == :up
  #   end
  # end

  # @tag :skip
  # describe "#push_button" do
  #   setup do
  #     %{car: Car.build(floor: 5)}
  #   end

  #   test "starts to open doors when is on destination floor and was idling", %{car: car} do
  #     car = car |> Car.push_button(car.current_floor)
  #     assert car.step == :doors_opening
  #   end

  #   test "starts to move up when is lower than destination and was idling" do
  #     car = %Car{current_floor: 5, step: nil} |> Car.push_button(6)
  #     assert car.step == :moving
  #     assert car.moving_direction == :up
  #     assert car.upper_destinations |> Prioqueue.peek_min!() == 6
  #   end
  # end

  defp build_car(additionals \\ []) do
    additionals |> Enum.reduce(Car.build([]), &Map.put(&2, elem(&1, 0), elem(&1, 1)))
  end
end
