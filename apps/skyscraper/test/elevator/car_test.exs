defmodule Skyscraper.Elevator.CarTest do
  alias Skyscraper.Elevator.{Car, Queue}
  use ExUnit.Case, async: true
  doctest Car

  test "builds a Car struct with the given params" do
    car = Car.build(current_floor: 5, floors: [4, 5, 6])
    assert %Car{} = car
    assert car |> Car.current_floor() == 5
    assert car.acceptable_floors == [4, 5, 6]
    assert car |> Car.step() == :idling
    assert %Queue{} = car.queue
  end

  test "returns all acceptable floors" do
    assert Car.build() |> Car.acceptable_floors() == 1..50 |> Enum.to_list()
    assert Car.build(floors: [1, 2, 3]) |> Car.acceptable_floors() == [1, 2, 3]
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

  test "returns current step" do
    assert Car.build() |> Car.step() == :idling
    assert build_car(step: :moving_up) |> Car.step() == :moving_up
  end

  test "returns step duration" do
    assert build_car(step_duration: 1000) |> Car.step_duration() == 1000
  end

  describe "#push_button" do
    test "opens the doors when idling and is on the destination floor" do
      car = build_car(current_floor: 6)
      assert car |> Car.step() == :idling
      assert car |> Car.current_floor() == 6
      assert car |> Car.floors_to_handle() |> Enum.empty?()

      {instructions, car} = car |> Car.push_button(6)
      assert car |> Car.step() == :opening_doors
      assert car |> Car.floors_to_handle() |> Enum.empty?()

      assert instructions == [:reserve_step_time]
    end

    test "starts moving and gives start instructions when idling and isn't on the destination floor" do
      car = build_car()
      assert car |> Car.step() == :idling
      assert car |> Car.current_floor() == 1
      assert car |> Car.floors_to_handle() |> Enum.empty?()

      {instructions, car} = car |> Car.push_button(6)
      assert car |> Car.step() == :moving_up
      assert 6 in Car.floors_to_handle(car)
      assert instructions == [:reserve_step_time]
    end

    test "ignores the command when new floor request is destination floor and car isn't idling" do
      car = build_car(destination: {6, :up}, step: :moving_up)
      {instructions, new_car} = car |> Car.push_button(6)

      assert car == new_car
      assert instructions |> Enum.empty?()
    end

    test "ignores the command when new floor request is current floor and car is opening doors" do
      car = build_car(current_floor: 6, step: :opening_doors)
      {instructions, new_car} = car |> Car.push_button(6)

      assert car == new_car
      assert instructions |> Enum.empty?()
    end

    test "puts new destination when destination is nil" do
      car = build_car(current_floor: 5, step: :closing_doors)
      assert Car.floors_to_handle(car) == []
      {instructions, car} = car |> Car.push_button(6)

      assert 6 in Car.floors_to_handle(car)
      assert car |> Car.step() == :closing_doors
      assert instructions |> Enum.empty?()
    end

    test "puts request to queue when moving and request is the current floor" do
      car = build_car(step: :moving_up, destination: {5, :up})
      assert car |> Car.current_floor() == 1
      assert car |> Car.floors_to_handle() == [5]
      {instructions, car} = car |> Car.push_button(1)

      assert car |> Car.floors_to_handle() == [5, 1]
      assert car |> Car.step() == :moving_up
      assert instructions |> Enum.empty?()
    end

    test "changes the destination and puts the old one to queue when request is between current floor and destination" do
      car = build_car(step: :moving_up, destination: {5, :up})
      assert car |> Car.current_floor() == 1
      assert car |> Car.floors_to_handle() == [5]
      {instructions, car} = car |> Car.push_button(3)

      assert car |> Car.floors_to_handle() == [3, 5]
      assert car |> Car.step() == :moving_up
      assert instructions == [:notify_new_destination]
    end

    test "puts it to queue when request isn't between current floor and destination" do
      car = build_car(step: :moving_up, destination: {5, :up})
      assert car |> Car.current_floor() == 1
      assert car |> Car.floors_to_handle() == [5]
      {instructions, car} = car |> Car.push_button(7)

      assert car |> Car.floors_to_handle() == [5, 7]
      assert car |> Car.step() == :moving_up
      assert instructions |> Enum.empty?()
    end

    test "prioritizes down direction requests when descending" do
      car =
        [
          step: :moving,
          direction: :down,
          destination: {7, :up},
          current_floor: 9
        ]
        |> build_car()

      assert car |> Car.floors_to_handle() == [7]

      {instructions, car} = car |> Car.push_button(6)

      assert car |> Car.floors_to_handle() == [6, 7]
      assert car |> Car.step() == :moving_down
      assert instructions == [:notify_new_destination]
    end

    # test "TEST" do
    #   car =
    #     [
    #       step: :moving,
    #       direction: :down,
    #       destination: {5, :up},
    #       current_floor: 7
    #     ]
    #     |> build_car()

    #   assert car |> Car.floors_to_handle() == [5]

    #   {instructions, car} = car |> Car.push_button(9)

    #   assert car |> Car.floors_to_handle() == [5, 9]
    #   assert car |> Car.step() == :moving_down
    #   assert instructions == []
    # end

    test "prioritizes up direction requests when ascending" do
      car =
        [
          step: :moving,
          direction: :up,
          destination: {7, :down}
        ]
        |> build_car()

      assert car |> Car.floors_to_handle() == [7]

      {instructions, car} = car |> Car.push_button(8)

      assert car |> Car.floors_to_handle() == [8, 7]
      assert car |> Car.step() == :moving_up
      assert instructions == [:notify_new_destination]
    end
  end

  describe "#complete_step" do
    test "opens the doors when they were started to open" do
      {instructions, car} = build_car(step: :opening_doors) |> Car.complete_step()

      assert car |> Car.step() == :doors_open
      assert instructions == [:reserve_step_time]
    end

    test "starts to close the doors when they were opened" do
      {instructions, car} = build_car(step: :doors_open) |> Car.complete_step()

      assert car |> Car.step() == :closing_doors
      assert instructions == [:reserve_step_time]
    end

    test "ascends one floor and keeps moving up when destination isn't reached" do
      {instructions, car} =
        [step: :moving, direction: :up, destination: {6, :up}]
        |> build_car()
        |> Car.complete_step()

      assert car |> Car.current_floor() == 2
      assert car |> Car.step() == :moving_up
      assert instructions == [:reserve_step_time]
    end

    test "ascends one floor and starts to open doors when destination is reached" do
      car = [step: :moving, direction: :up, destination: {2, :up}] |> build_car()
      assert car |> Car.floors_to_handle() == [2]

      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.current_floor() == 2
      assert car |> Car.step() == :opening_doors
      assert car |> Car.floors_to_handle() == []
      assert instructions == [:reserve_step_time]
    end

    test "descends one floor and keeps moving down when destination isn't reached" do
      {instructions, car} =
        [step: :moving, direction: :down, destination: {6, :down}, current_floor: 8]
        |> build_car()
        |> Car.complete_step()

      assert car |> Car.current_floor() == 7
      assert car |> Car.step() == :moving_down
      assert instructions == [:reserve_step_time]
    end

    test "descends one floor and starts to open doors when destination is reached by moving down" do
      car =
        [step: :moving, direction: :down, destination: {2, :down}, current_floor: 3]
        |> build_car()

      assert car |> Car.floors_to_handle() == [2]

      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.current_floor() == 2
      assert car |> Car.step() == :opening_doors
      assert car |> Car.floors_to_handle() == []
      assert instructions == [:reserve_step_time]
    end

    test "becomes idle when there are no more destinations on closing doors" do
      {instructions, car} =
        [step: :closing_doors, destination: nil]
        |> build_car()
        |> Car.complete_step()

      assert car |> Car.step() == :idling
      assert instructions == [:notify_new_destination]
    end

    test "starts to ascend on closing doors when next destination is above current floor" do
      {instructions, car} =
        [step: :closing_doors, destination: {3, :up}]
        |> build_car()
        |> Car.complete_step()

      assert car |> Car.step() == :moving_up

      assert :reserve_step_time in instructions
      assert :notify_new_destination in instructions
    end

    test "starts to descend on closing doors when next destination is under current floor" do
      {instructions, car} =
        [step: :closing_doors, destination: {3, :up}, current_floor: 5]
        |> build_car()
        |> Car.complete_step()

      assert car |> Car.step() == :moving_down

      assert :reserve_step_time in instructions
      assert :notify_new_destination in instructions
    end

    test "starts to open doors on closing doors when next destination is current floor" do
      {instructions, car} =
        [step: :closing_doors, destination: {3, :up}, current_floor: 3]
        |> build_car()
        |> Car.complete_step()

      assert car |> Car.step() == :opening_doors

      assert :reserve_step_time in instructions
      assert :notify_new_destination in instructions
    end

    test "fetches new destination from queue when reached the current destination" do
      car =
        [
          step: :moving,
          direction: :up,
          destination: {2, :up},
          queue: Queue.build() |> Queue.push({6, :up}) |> Queue.push({4, :down})
        ]
        |> build_car()

      assert car |> Car.floors_to_handle() |> Enum.sort() == [2, 4, 6]

      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.current_floor() == 2
      assert car |> Car.step() == :opening_doors
      assert car |> Car.floors_to_handle() |> Enum.sort() == [4, 6]
      assert instructions == [:reserve_step_time]
    end
  end

  defp build_car(additionals \\ []) do
    additionals |> Enum.reduce(Car.build([]), &Map.put(&2, elem(&1, 0), elem(&1, 1)))
  end
end
