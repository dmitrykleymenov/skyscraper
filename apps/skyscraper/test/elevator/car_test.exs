defmodule Skyscraper.Elevator.CarTest do
  alias Skyscraper.Elevator.{Car, Queue}
  use ExUnit.Case, async: true
  # doctest Car

  setup context do
    car =
      context
      |> Map.get(:additionals, [])
      |> Enum.reduce(Car.build([]), &Map.put(&2, elem(&1, 0), elem(&1, 1)))

    %{car: car}
  end

  test "builds a Car struct with the given params" do
    car = Car.build(current_floor: 5, floors: [4, 5, 6])
    assert %Car{} = car
    assert car |> Car.current_floor() == 5
    assert car.acceptable_floors == [4, 5, 6]
    assert car |> Car.step() == :idling
    assert %Queue{} = car.queue
  end

  test "returns all acceptable floors", %{car: car} do
    assert car |> Car.acceptable_floors() == 1..50 |> Enum.to_list()
    assert Car.build(floors: [1, 2, 3]) |> Car.acceptable_floors() == [1, 2, 3]
  end

  test "returns empty list when nothing to handle", %{car: car} do
    assert car |> Car.floors_to_handle() == []
  end

  @tag additionals: [
         destination: {5, :up},
         queue: Queue.build() |> Queue.push({6, :up}) |> Queue.push({4, :down})
       ]

  test "returns all floors to handle", %{car: car} do
    assert car |> Car.floors_to_handle() |> Enum.sort() == [4, 5, 6]
  end

  @tag additionals: [current_floor: 5]
  test "returns current floor", %{car: car} do
    assert car |> Car.current_floor() == 5
  end

  test "returns default floor when floor wasn't provided", %{car: car} do
    assert car |> Car.current_floor() == 1
  end

  @tag additionals: [step: :moving, direction: :up]
  test "returns current step", %{car: car} do
    assert car |> Car.step() == :moving_up
  end

  test "returns idling on the start", %{car: car} do
    assert car |> Car.step() == :idling
  end

  @tag additionals: [step: :moving, direction: :up, step_durations: %{moving_up: 3000}]
  test "returns appropriate step duration", %{car: car} do
    assert car |> Car.step_duration() == 3000
  end

  test "returns default if step duration wasn't provided", %{car: car} do
    assert car |> Car.step_duration() == 1000
  end

  describe ".push_button/2" do
    @tag additionals: [current_floor: 6]
    test "opens the doors when idling and is on the destination floor", %{car: car} do
      assert car |> Car.step() == :idling
      assert car |> Car.current_floor() == 6
      assert car |> Car.floors_to_handle() |> Enum.empty?()

      {instructions, car} = car |> Car.push_button(6)
      assert car |> Car.step() == :opening_doors
      assert car |> Car.floors_to_handle() |> Enum.empty?()

      assert instructions == [:reserve_step_time]
    end

    test "starts moving and gives start instructions when idling and isn't on the destination floor",
         %{car: car} do
      assert car |> Car.step() == :idling
      assert car |> Car.current_floor() == 1
      assert car |> Car.floors_to_handle() |> Enum.empty?()

      {instructions, car} = car |> Car.push_button(6)
      assert car |> Car.step() == :moving_up
      assert 6 in Car.floors_to_handle(car)
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [destination: {6, :up}, step: :moving, direction: :up]
    test "ignores the command when new floor request is destination floor and car isn't idling",
         %{car: car} do
      {instructions, new_car} = car |> Car.push_button(6)

      assert car == new_car
      assert instructions |> Enum.empty?()
    end

    @tag additionals: [current_floor: 6, step: :opening_doors]
    test "ignores the command when new floor request is current floor and car is opening doors",
         %{car: car} do
      {instructions, new_car} = car |> Car.push_button(6)

      assert car == new_car
      assert instructions |> Enum.empty?()
    end

    @tag additionals: [current_floor: 5, step: :closing_doors]
    test "puts new destination when destination is nil", %{car: car} do
      assert car |> Car.floors_to_handle() == []
      {instructions, car} = car |> Car.push_button(6)

      assert 6 in Car.floors_to_handle(car)
      assert car |> Car.step() == :closing_doors
      assert instructions |> Enum.empty?()
    end

    @tag additionals: [step: :moving, direction: :up, destination: {5, :up}]
    test "puts request to queue when moving and request is the current floor", %{car: car} do
      assert car |> Car.current_floor() == 1
      assert car |> Car.floors_to_handle() == [5]
      {instructions, car} = car |> Car.push_button(1)

      assert car |> Car.floors_to_handle() == [5, 1]
      assert car |> Car.step() == :moving_up
      assert instructions |> Enum.empty?()
    end

    @tag additionals: [step: :moving, direction: :up, destination: {5, :up}]
    test "changes the destination and puts the old one to queue when request is between current floor and destination",
         %{car: car} do
      assert car |> Car.current_floor() == 1
      assert car |> Car.floors_to_handle() == [5]
      {instructions, car} = car |> Car.push_button(3)

      assert car |> Car.floors_to_handle() == [3, 5]
      assert car |> Car.step() == :moving_up
      assert instructions == [:notify_new_destination]
    end

    @tag additionals: [step: :moving, direction: :up, destination: {5, :up}]
    test "puts it to queue when request isn't between current floor and destination", %{car: car} do
      assert car |> Car.current_floor() == 1
      assert car |> Car.floors_to_handle() == [5]
      {instructions, car} = car |> Car.push_button(7)

      assert car |> Car.floors_to_handle() == [5, 7]
      assert car |> Car.step() == :moving_up
      assert instructions |> Enum.empty?()
    end

    @tag additionals: [
           step: :moving,
           direction: :down,
           destination: {7, :up},
           current_floor: 9
         ]
    test "prioritizes down direction requests when descending", %{car: car} do
      assert car |> Car.floors_to_handle() == [7]

      {instructions, car} = car |> Car.push_button(6)

      assert car |> Car.floors_to_handle() == [6, 7]
      assert car |> Car.step() == :moving_down
      assert instructions == [:notify_new_destination]
    end

    @tag additionals: [step: :moving, direction: :up, destination: {7, :down}]
    test "prioritizes up direction requests when ascending", %{car: car} do
      assert car |> Car.floors_to_handle() == [7]

      {instructions, car} = car |> Car.push_button(8)

      assert car |> Car.floors_to_handle() == [8, 7]
      assert car |> Car.step() == :moving_up
      assert instructions == [:notify_new_destination]
    end
  end

  describe ".can_handle?/2" do
    test "thuthy when destination is empty", %{car: car} do
      assert car |> Car.can_handle?({5, :up})
    end

    @tag additionals: [acceptable_floors: [3, 4, 6]]
    test "falsey when request out of accaptable floors range", %{car: car} do
      refute car |> Car.can_handle?({5, :up})
    end

    @tag additionals: [destination: {5, :up}, current_floor: 3]
    test "falsey when request moving choice is up and destination is below", %{car: car} do
      refute car |> Car.can_handle?({7, :up})
    end

    @tag additionals: [destination: {5, :down}, current_floor: 7]
    test "falsey when request moving choice is down and destination is above", %{car: car} do
      refute car |> Car.can_handle?({3, :up})
    end

    @tag additionals: [destination: {5, :down}, current_floor: 7]
    test "falsey when request floor is destination floor and moving choices are different", %{
      car: car
    } do
      refute car |> Car.can_handle?({5, :up})
    end

    @tag additionals: [destination: {5, :down}, current_floor: 7]
    test "truthy when request is equal to destination", %{car: car} do
      assert car |> Car.can_handle?({5, :down})
    end

    @tag additionals: [destination: {3, :down}, current_floor: 5]
    test "truthy when step isn't moving and request is the current floor with down moving choice",
         %{car: car} do
      assert car |> Car.can_handle?({5, :down})
    end

    @tag additionals: [destination: {7, :down}, current_floor: 5]
    test "truthy when step isn't moving and request is the current floor with up moving choice",
         %{car: car} do
      assert car |> Car.can_handle?({5, :up})
    end

    @tag additionals: [step: :moving, destination: {7, :up}, current_floor: 5]
    test "falsey when step moving and request is the current floor with up moving choice", %{
      car: car
    } do
      refute car |> Car.can_handle?({5, :up})
    end

    @tag additionals: [destination: {7, :up}, current_floor: 5]
    test "falsey when current floor in between destination and request", %{car: car} do
      refute car |> Car.can_handle?({3, :up})
    end

    @tag additionals: [destination: {5, :up}, current_floor: 2]
    test "falsey when request is further than destination and destination moving choice is up", %{
      car: car
    } do
      refute car |> Car.can_handle?({7, :down})
    end

    @tag additionals: [destination: {5, :down}, current_floor: 7]
    test "falsey when request is further than destination and destination moving choice is down",
         %{car: car} do
      refute car |> Car.can_handle?({3, :up})
    end

    @tag additionals: [destination: {5, :up}, current_floor: 7]
    test "truthy when request is further than destination but has the same moving choice", %{
      car: car
    } do
      assert car |> Car.can_handle?({3, :up})
    end

    @tag additionals: [destination: {5, :down}, current_floor: 9]
    test "truthy when request is on the way to destination", %{car: car} do
      assert car |> Car.can_handle?({7, :down})
    end
  end

  describe ".complete_step/1" do
    @tag additionals: [step: :opening_doors]
    test "opens the doors when they were started to open", %{car: car} do
      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.step() == :doors_open
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [step: :doors_open]
    test "starts to close the doors when they were opened", %{car: car} do
      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.step() == :closing_doors
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [step: :moving, direction: :up, destination: {6, :up}]
    test "ascends one floor and keeps moving up when destination isn't reached", %{car: car} do
      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.current_floor() == 2
      assert car |> Car.step() == :moving_up
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [step: :moving, direction: :up, destination: {2, :up}]
    test "ascends one floor and starts to open doors when destination is reached", %{car: car} do
      assert car |> Car.floors_to_handle() == [2]

      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.current_floor() == 2
      assert car |> Car.step() == :opening_doors
      assert car |> Car.floors_to_handle() == []
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [step: :moving, direction: :down, destination: {6, :down}, current_floor: 8]
    test "descends one floor and keeps moving down when destination isn't reached", %{car: car} do
      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.current_floor() == 7
      assert car |> Car.step() == :moving_down
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [step: :moving, direction: :down, destination: {2, :down}, current_floor: 3]
    test "descends one floor and starts to open doors when destination is reached by moving down",
         %{car: car} do
      assert car |> Car.floors_to_handle() == [2]

      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.current_floor() == 2
      assert car |> Car.step() == :opening_doors
      assert car |> Car.floors_to_handle() == []
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [step: :closing_doors, destination: nil]
    test "becomes idle when there are no more destinations on closing doors", %{car: car} do
      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.step() == :idling
      assert instructions == [:notify_new_destination]
    end

    @tag additionals: [step: :closing_doors, destination: {3, :up}]
    test "starts to ascend on closing doors when next destination is above", %{car: car} do
      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.step() == :moving_up
      assert :reserve_step_time in instructions
      assert :notify_new_destination in instructions
    end

    @tag additionals: [step: :closing_doors, destination: {3, :up}, current_floor: 5]
    test "starts to descend on closing doors when next destination is below", %{car: car} do
      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.step() == :moving_down
      assert :reserve_step_time in instructions
      assert :notify_new_destination in instructions
    end

    @tag additionals: [step: :closing_doors, destination: {3, :up}, current_floor: 3]
    test "starts to open doors on closing doors when next destination is current floor", %{
      car: car
    } do
      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.step() == :opening_doors
      assert :reserve_step_time in instructions
      assert :notify_new_destination in instructions
    end

    @tag additionals: [
           step: :moving,
           direction: :up,
           destination: {2, :up},
           queue: Queue.build() |> Queue.push({6, :up}) |> Queue.push({4, :down})
         ]
    test "fetches new destination from queue when reached the current destination", %{car: car} do
      assert car |> Car.floors_to_handle() |> Enum.sort() == [2, 4, 6]

      {instructions, car} = car |> Car.complete_step()

      assert car |> Car.current_floor() == 2
      assert car |> Car.step() == :opening_doors
      assert car |> Car.floors_to_handle() |> Enum.sort() == [4, 6]
      assert instructions == [:reserve_step_time]
    end
  end

  describe ".additional_handling_time/2" do
    setup %{car: car} do
      car =
        car
        |> Map.put(:step_durations, %{
          opening_doors: 1,
          doors_open: 10,
          closing_doors: 100,
          moving_up: 1000,
          moving_down: 10000
        })

      %{car: car}
    end

    @tag additionals: [destination: {6, :up}, current_floor: 2, step: :moving, direction: :up]
    test "returns only doors status changing time when request direction is up and destination on the way",
         %{
           car: car
         } do
      assert car |> Car.additional_handling_time({4, :up}) == 111
    end

    @tag additionals: [destination: {3, :down}, current_floor: 8, step: :moving, direction: :down]
    test "returns only doors status changing time when request direction is down and destination on the way",
         %{
           car: car
         } do
      assert car |> Car.additional_handling_time({5, :down}) == 111
    end

    @tag additionals: [destination: {5, :up}, current_floor: 7, step: :moving, direction: :down]
    test "returns doors status changing, ascend and descend time when destination is lower than request and request moving choice is up",
         %{
           car: car
         } do
      assert car |> Car.additional_handling_time({3, :up}) == 22111
    end

    @tag additionals: [destination: {5, :down}, current_floor: 2, step: :moving, direction: :down]
    test "returns doors status changing, ascend and descend time when destination is higher than request and request moving choice is down",
         %{
           car: car
         } do
      assert car |> Car.additional_handling_time({7, :down}) == 22111
    end
  end
end
