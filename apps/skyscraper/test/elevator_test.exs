defmodule Skyscraper.ElevatorTest do
  alias Skyscraper.Elevator
  alias Skyscraper.Elevator.Queue
  use ExUnit.Case, async: true
  # doctest Elevator

  setup context do
    elevator =
      context
      |> Map.get(:additionals, [])
      |> Enum.reduce(Elevator.build([]), &Map.put(&2, elem(&1, 0), elem(&1, 1)))

    %{elevator: elevator}
  end

  test "builds a Elevator struct with the given params" do
    elevator = Elevator.build(current_floor: 5, floors: [4, 5, 6])
    assert %Elevator{} = elevator
    assert elevator |> Elevator.current_floor() == 5
    assert elevator.acceptable_floors == [4, 5, 6]
    assert elevator |> Elevator.step() == :idling
    assert %Queue{} = elevator.queue
  end

  test "returns all acceptable floors", %{elevator: elevator} do
    assert elevator |> Elevator.acceptable_floors() == 1..50 |> Enum.to_list()
    assert Elevator.build(floors: [1, 2, 3]) |> Elevator.acceptable_floors() == [1, 2, 3]
  end

  test "returns empty list when nothing to handle", %{elevator: elevator} do
    assert elevator |> Elevator.floors_to_handle() == []
  end

  @tag additionals: [
         destination: {5, :up},
         queue: Queue.build() |> Queue.push({6, :up}) |> Queue.push({4, :down})
       ]

  test "returns all floors to handle", %{elevator: elevator} do
    assert elevator |> Elevator.floors_to_handle() |> Enum.sort() == [4, 5, 6]
  end

  @tag additionals: [
         destination: {5, :up},
         outer_request: true,
         queue: Queue.build() |> Queue.push({6, :up}) |> Queue.push({4, :down})
       ]

  test "returns all floors to handle except outers", %{elevator: elevator} do
    assert elevator |> Elevator.floors_to_handle() |> Enum.sort() == [4, 6]
  end

  @tag additionals: [current_floor: 5]
  test "returns current floor", %{elevator: elevator} do
    assert elevator |> Elevator.current_floor() == 5
  end

  test "returns default floor when floor wasn't provided", %{elevator: elevator} do
    assert elevator |> Elevator.current_floor() == 1
  end

  @tag additionals: [step: :moving, direction: :up]
  test "returns current step", %{elevator: elevator} do
    assert elevator |> Elevator.step() == :moving_up
  end

  test "returns idling on the start", %{elevator: elevator} do
    assert elevator |> Elevator.step() == :idling
  end

  @tag additionals: [step: :moving, direction: :up, step_durations: %{moving_up: 3000}]
  test "returns appropriate step duration", %{elevator: elevator} do
    assert elevator |> Elevator.step_duration() == 3000
  end

  test "returns default if step duration wasn't provided", %{elevator: elevator} do
    assert elevator |> Elevator.step_duration() == 1000
  end

  describe ".push_button/2" do
    @tag additionals: [current_floor: 6]
    test "opens the doors when idling and is on the destination floor", %{elevator: elevator} do
      assert elevator |> Elevator.step() == :idling
      assert elevator |> Elevator.current_floor() == 6
      assert elevator |> Elevator.floors_to_handle() |> Enum.empty?()

      {instructions, elevator} = elevator |> Elevator.push_button(6)
      assert elevator |> Elevator.step() == :opening_doors
      assert elevator |> Elevator.floors_to_handle() |> Enum.empty?()

      assert instructions == [:reserve_step_time]
    end

    test "starts moving and gives start instructions when idling and isn't on the destination floor",
         %{elevator: elevator} do
      assert elevator |> Elevator.step() == :idling
      assert elevator |> Elevator.current_floor() == 1
      assert elevator |> Elevator.floors_to_handle() |> Enum.empty?()

      {instructions, elevator} = elevator |> Elevator.push_button(6)
      assert elevator |> Elevator.step() == :moving_up
      assert 6 in Elevator.floors_to_handle(elevator)
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [destination: {6, :up}, outer_request: true, step: :moving, direction: :up]
    test "add floor to query if floor is equal destination, but destination is outer request",
         %{elevator: elevator} do
      assert elevator |> Elevator.floors_to_handle() |> Enum.empty?()
      {instructions, elevator} = elevator |> Elevator.push_button(6)

      assert elevator |> Elevator.floors_to_handle() == [6]
      assert instructions |> Enum.empty?()
    end

    @tag additionals: [destination: {6, :up}, step: :moving, direction: :up]
    test "ignores the command when new floor request is destination floor and elevator isn't idling",
         %{elevator: elevator} do
      {instructions, new_elevator} = elevator |> Elevator.push_button(6)

      assert elevator == new_elevator
      assert instructions |> Enum.empty?()
    end

    @tag additionals: [current_floor: 6, step: :opening_doors]
    test "ignores the command when new floor request is current floor and elevator is opening doors",
         %{elevator: elevator} do
      {instructions, new_elevator} = elevator |> Elevator.push_button(6)

      assert elevator == new_elevator
      assert instructions |> Enum.empty?()
    end

    @tag additionals: [current_floor: 5, step: :closing_doors]
    test "puts new destination when destination is nil", %{elevator: elevator} do
      assert elevator |> Elevator.floors_to_handle() == []
      {instructions, elevator} = elevator |> Elevator.push_button(6)

      assert 6 in Elevator.floors_to_handle(elevator)
      assert elevator |> Elevator.step() == :closing_doors
      assert instructions |> Enum.empty?()
    end

    @tag additionals: [step: :moving, direction: :up, destination: {5, :up}]
    test "puts request to queue when moving and request is the current floor", %{
      elevator: elevator
    } do
      assert elevator |> Elevator.current_floor() == 1
      assert elevator |> Elevator.floors_to_handle() == [5]
      {instructions, elevator} = elevator |> Elevator.push_button(1)

      assert elevator |> Elevator.floors_to_handle() == [5, 1]
      assert elevator |> Elevator.step() == :moving_up
      assert instructions |> Enum.empty?()
    end

    @tag additionals: [step: :moving, direction: :up, destination: {5, :up}, outer_request: true]
    test "sets the destination and discards the old one when outer request request is between current floor and destination",
         %{elevator: elevator} do
      assert elevator |> Elevator.current_floor() == 1
      assert elevator.outer_request
      assert elevator |> Elevator.floors_to_handle() == []
      {instructions, elevator} = elevator |> Elevator.push_button(3)

      assert elevator |> Elevator.floors_to_handle() == [3]
      refute elevator.outer_request
      assert elevator |> Elevator.step() == :moving_up
      assert instructions == [:notify_new_destination]
    end

    @tag additionals: [step: :moving, direction: :up, destination: {5, :up}]
    test "changes the destination and puts the old one to queue when request is between current floor and destination",
         %{elevator: elevator} do
      assert elevator |> Elevator.current_floor() == 1
      assert elevator |> Elevator.floors_to_handle() == [5]
      {instructions, elevator} = elevator |> Elevator.push_button(3)

      assert elevator |> Elevator.floors_to_handle() == [3, 5]
      assert elevator |> Elevator.step() == :moving_up
      assert instructions == [:notify_new_destination]
    end

    @tag additionals: [step: :moving, direction: :up, destination: {5, :up}]
    test "puts it to queue when request isn't between current floor and destination", %{
      elevator: elevator
    } do
      assert elevator |> Elevator.current_floor() == 1
      assert elevator |> Elevator.floors_to_handle() == [5]
      {instructions, elevator} = elevator |> Elevator.push_button(7)

      assert elevator |> Elevator.floors_to_handle() == [5, 7]
      assert elevator |> Elevator.step() == :moving_up
      assert instructions |> Enum.empty?()
    end

    @tag additionals: [
           step: :moving,
           direction: :down,
           destination: {7, :up},
           current_floor: 9
         ]
    test "prioritizes down direction requests when descending", %{elevator: elevator} do
      assert elevator |> Elevator.floors_to_handle() == [7]

      {instructions, elevator} = elevator |> Elevator.push_button(6)

      assert elevator |> Elevator.floors_to_handle() == [6, 7]
      assert elevator |> Elevator.step() == :moving_down
      assert instructions == [:notify_new_destination]
    end

    @tag additionals: [
           step: :moving,
           direction: :down,
           destination: {7, :up},
           current_floor: 9,
           outer_request: true
         ]
    test "prioritizes down direction requests when descending and outer request", %{
      elevator: elevator
    } do
      assert elevator |> Elevator.floors_to_handle() == []

      {instructions, elevator} = elevator |> Elevator.push_button(6)

      assert elevator |> Elevator.floors_to_handle() == [6]
      assert elevator |> Elevator.step() == :moving_down
      assert instructions == [:notify_new_destination]
    end

    @tag additionals: [step: :moving, direction: :up, destination: {7, :down}]
    test "prioritizes up direction requests when ascending", %{elevator: elevator} do
      assert elevator |> Elevator.floors_to_handle() == [7]

      {instructions, elevator} = elevator |> Elevator.push_button(8)

      assert elevator |> Elevator.floors_to_handle() == [8, 7]
      assert elevator |> Elevator.step() == :moving_up
      assert instructions == [:notify_new_destination]
    end
  end

  describe ".can_handle?/2" do
    test "thuthy when destination is empty", %{elevator: elevator} do
      assert elevator |> Elevator.can_handle?({5, :up})
    end

    @tag additionals: [acceptable_floors: [3, 4, 6]]
    test "falsey when request out of accaptable floors range", %{elevator: elevator} do
      refute elevator |> Elevator.can_handle?({5, :up})
    end

    @tag additionals: [destination: {5, :up}, current_floor: 3]
    test "falsey when request moving choice is up and destination is below", %{elevator: elevator} do
      refute elevator |> Elevator.can_handle?({7, :up})
    end

    @tag additionals: [destination: {5, :down}, current_floor: 7]
    test "falsey when request moving choice is down and destination is above", %{
      elevator: elevator
    } do
      refute elevator |> Elevator.can_handle?({3, :up})
    end

    @tag additionals: [destination: {5, :down}, current_floor: 7]
    test "falsey when request floor is destination floor and moving choices are different", %{
      elevator: elevator
    } do
      refute elevator |> Elevator.can_handle?({5, :up})
    end

    @tag additionals: [destination: {5, :down}, current_floor: 7]
    test "truthy when request is equal to destination", %{elevator: elevator} do
      assert elevator |> Elevator.can_handle?({5, :down})
    end

    @tag additionals: [destination: {3, :down}, current_floor: 5]
    test "truthy when step isn't moving and request is the current floor with down moving choice",
         %{elevator: elevator} do
      assert elevator |> Elevator.can_handle?({5, :down})
    end

    @tag additionals: [destination: {7, :down}, current_floor: 5]
    test "truthy when step isn't moving and request is the current floor with up moving choice",
         %{elevator: elevator} do
      assert elevator |> Elevator.can_handle?({5, :up})
    end

    @tag additionals: [step: :moving, destination: {7, :up}, current_floor: 5]
    test "falsey when step moving and request is the current floor with up moving choice", %{
      elevator: elevator
    } do
      refute elevator |> Elevator.can_handle?({5, :up})
    end

    @tag additionals: [destination: {7, :up}, current_floor: 5]
    test "falsey when current floor in between destination and request", %{elevator: elevator} do
      refute elevator |> Elevator.can_handle?({3, :up})
    end

    @tag additionals: [destination: {5, :up}, current_floor: 2]
    test "falsey when request is further than destination and destination moving choice is up", %{
      elevator: elevator
    } do
      refute elevator |> Elevator.can_handle?({7, :down})
    end

    @tag additionals: [destination: {5, :down}, current_floor: 7]
    test "falsey when request is further than destination and destination moving choice is down",
         %{elevator: elevator} do
      refute elevator |> Elevator.can_handle?({3, :up})
    end

    @tag additionals: [destination: {5, :up}, current_floor: 7]
    test "truthy when request is further than destination but has the same moving choice", %{
      elevator: elevator
    } do
      assert elevator |> Elevator.can_handle?({3, :up})
    end

    @tag additionals: [destination: {5, :down}, current_floor: 9]
    test "truthy when request is on the way to destination", %{elevator: elevator} do
      assert elevator |> Elevator.can_handle?({7, :down})
    end
  end

  describe ".complete_step/1" do
    @tag additionals: [step: :opening_doors]
    test "opens the doors when they were started to open", %{elevator: elevator} do
      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.step() == :doors_open
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [step: :doors_open]
    test "starts to close the doors when they were opened", %{elevator: elevator} do
      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.step() == :closing_doors
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [step: :moving, direction: :up, destination: {6, :up}]
    test "ascends one floor and keeps moving up when destination isn't reached", %{
      elevator: elevator
    } do
      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.current_floor() == 2
      assert elevator |> Elevator.step() == :moving_up
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [step: :moving, direction: :up, destination: {2, :up}]
    test "ascends one floor and starts to open doors when destination is reached", %{
      elevator: elevator
    } do
      assert elevator |> Elevator.floors_to_handle() == [2]

      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.current_floor() == 2
      assert elevator |> Elevator.step() == :opening_doors
      assert elevator |> Elevator.floors_to_handle() == []
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [step: :moving, direction: :down, destination: {6, :down}, current_floor: 8]
    test "descends one floor and keeps moving down when destination isn't reached", %{
      elevator: elevator
    } do
      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.current_floor() == 7
      assert elevator |> Elevator.step() == :moving_down
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [
           step: :moving,
           direction: :down,
           destination: {6, :down},
           current_floor: 8,
           outer_request: true,
           step_durations: %{
             opening_doors: 1,
             doors_open: 10,
             closing_doors: 100,
             moving_up: 1000,
             moving_down: 10000
           }
         ]
    test "descends one floor, keeps moving down and sends destination reach time when destination isn't reached and request is outer",
         %{
           elevator: elevator
         } do
      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.current_floor() == 7
      assert elevator |> Elevator.step() == :moving_down
      assert :reserve_step_time in instructions
      assert {:send_time_to_destination, {{6, :down}, 10000}} in instructions
    end

    @tag additionals: [
           step: :opening_doors,
           direction: :up,
           destination: {6, :down},
           current_floor: 8,
           outer_request: true,
           step_durations: %{
             opening_doors: 1,
             doors_open: 10,
             closing_doors: 100,
             moving_up: 1000,
             moving_down: 10000
           }
         ]
    test "sends destination reach time when opening doors and request is outer",
         %{
           elevator: elevator
         } do
      {instructions, _elevator} = elevator |> Elevator.complete_step()

      assert {:send_time_to_destination, {{6, :down}, 20110}} in instructions
    end

    @tag additionals: [step: :moving, direction: :down, destination: {2, :down}, current_floor: 3]
    test "descends one floor and starts to open doors when destination is reached by moving down",
         %{elevator: elevator} do
      assert elevator |> Elevator.floors_to_handle() == [2]

      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.current_floor() == 2
      assert elevator |> Elevator.step() == :opening_doors
      assert elevator |> Elevator.floors_to_handle() == []
      assert instructions == [:reserve_step_time]
    end

    @tag additionals: [
           step: :moving,
           direction: :up,
           destination: {2, :up},
           outer_request: true,
           queue: Queue.build() |> Queue.push({2, :up})
         ]
    test "ignores the same floor destination from queue when reached outer request",
         %{
           elevator: elevator
         } do
      assert elevator |> Elevator.floors_to_handle() == [2]

      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.current_floor() == 2
      assert elevator |> Elevator.step() == :opening_doors
      assert elevator |> Elevator.floors_to_handle() == []
      assert instructions == [:reserve_step_time]
      refute elevator.outer_request
    end

    @tag additionals: [
           step: :moving,
           direction: :up,
           destination: {2, :up},
           outer_request: true,
           queue: Queue.build() |> Queue.push({3, :up})
         ]
    test "takes next destination from queue when reached outer request and current floor doesn't equal new destination",
         %{
           elevator: elevator
         } do
      assert elevator |> Elevator.floors_to_handle() == [3]

      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.current_floor() == 2
      assert elevator |> Elevator.step() == :opening_doors
      assert elevator |> Elevator.floors_to_handle() == [3]
      assert instructions == [:reserve_step_time]
      refute elevator.outer_request
    end

    @tag additionals: [step: :closing_doors, destination: nil]
    test "becomes idle when there are no more destinations on closing doors", %{
      elevator: elevator
    } do
      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.step() == :idling
      assert instructions == [:notify_new_destination]
    end

    @tag additionals: [step: :closing_doors, destination: {3, :up}]
    test "starts to ascend on closing doors when next destination is above", %{elevator: elevator} do
      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.step() == :moving_up
      assert :reserve_step_time in instructions
      assert :notify_new_destination in instructions
    end

    @tag additionals: [step: :closing_doors, destination: {3, :up}, current_floor: 5]
    test "starts to descend on closing doors when next destination is below", %{
      elevator: elevator
    } do
      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.step() == :moving_down
      assert :reserve_step_time in instructions
      assert :notify_new_destination in instructions
    end

    @tag additionals: [step: :closing_doors, destination: {3, :up}, current_floor: 3]
    test "starts to open doors on closing doors when next destination is current floor", %{
      elevator: elevator
    } do
      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.step() == :opening_doors
      assert :reserve_step_time in instructions
      assert :notify_new_destination in instructions
    end

    @tag additionals: [
           step: :moving,
           direction: :up,
           destination: {2, :up},
           queue: Queue.build() |> Queue.push({6, :up}) |> Queue.push({4, :down})
         ]
    test "fetches new destination from queue when reached the current destination", %{
      elevator: elevator
    } do
      assert elevator |> Elevator.floors_to_handle() |> Enum.sort() == [2, 4, 6]

      {instructions, elevator} = elevator |> Elevator.complete_step()

      assert elevator |> Elevator.current_floor() == 2
      assert elevator |> Elevator.step() == :opening_doors
      assert elevator |> Elevator.floors_to_handle() |> Enum.sort() == [4, 6]
      assert instructions == [:reserve_step_time]
    end
  end

  describe ".additional_handling_time/2" do
    setup %{elevator: elevator} do
      elevator =
        elevator
        |> Map.put(:step_durations, %{
          opening_doors: 1,
          doors_open: 10,
          closing_doors: 100,
          moving_up: 1000,
          moving_down: 10000
        })

      %{elevator: elevator}
    end

    @tag additionals: [destination: {6, :up}, current_floor: 2, step: :moving, direction: :up]
    test "returns only doors status changing time when request direction is up and destination on the way",
         %{
           elevator: elevator
         } do
      assert elevator |> Elevator.additional_handling_time({4, :up}) == 111
    end

    @tag additionals: [destination: {3, :down}, current_floor: 8, step: :moving, direction: :down]
    test "returns only doors status changing time when request direction is down and destination on the way",
         %{
           elevator: elevator
         } do
      assert elevator |> Elevator.additional_handling_time({5, :down}) == 111
    end

    @tag additionals: [destination: {5, :up}, current_floor: 7, step: :moving, direction: :down]
    test "returns doors status changing, ascend and descend time when destination is lower than request and request moving choice is up",
         %{
           elevator: elevator
         } do
      assert elevator |> Elevator.additional_handling_time({3, :up}) == 22111
    end

    @tag additionals: [destination: {5, :down}, current_floor: 2, step: :moving, direction: :down]
    test "returns doors status changing, ascend and descend time when destination is higher than request and request moving choice is down",
         %{
           elevator: elevator
         } do
      assert elevator |> Elevator.additional_handling_time({7, :down}) == 22111
    end

    @tag additionals: [
           destination: {7, :down},
           current_floor: 10,
           step: :moving,
           direction: :down,
           queue: Queue.build() |> Queue.push({5, :down}) |> Queue.push({6, :down})
         ]
    test "returns only delta for handling times", %{elevator: elevator} do
      assert elevator |> Elevator.additional_handling_time({8, :down}) == 111
    end
  end

  describe(".propose/2") do
    @tag additionals: [destination: {7, :up}, step: :moving, direction: :up]
    test "ignores destinations when can't handle any of them", %{elevator: elevator} do
      assert elevator |> Elevator.propose([{{5, :down}, nil}, {{1, :up}, nil}]) == :ignored
    end

    @tag additionals: [destination: {7, :up}, step: :moving, direction: :up]
    test "accepts a destination when can handle it", %{elevator: elevator} do
      assert {:accepted, {{5, :up}, 4000}, %Elevator{}} =
               elevator |> Elevator.propose([{{5, :up}, nil}])
    end

    @tag additionals: [destination: {7, :up}, step: :moving, direction: :up]
    test "ignores destination if handling time more than given", %{elevator: elevator} do
      assert elevator |> Elevator.propose([{{5, :up}, 3000}]) == :ignored
    end

    @tag additionals: [destination: {7, :up}, step: :moving, direction: :up]
    test "takes destination which can handle and ignores other", %{elevator: elevator} do
      assert {:accepted, {{5, :up}, 4000}, %Elevator{}} =
               elevator |> Elevator.propose([{{1, :up}, nil}, {{5, :up}, nil}, {{9, :up}, nil}])
    end

    @tag additionals: [destination: {7, :up}, step: :moving, direction: :up]
    test "takes last destination can handle", %{elevator: elevator} do
      assert {:accepted, {{2, :up}, 1000}, %Elevator{}} =
               elevator |> Elevator.propose([{{5, :up}, nil}, {{2, :up}, nil}, {{9, :up}, nil}])
    end
  end
end
