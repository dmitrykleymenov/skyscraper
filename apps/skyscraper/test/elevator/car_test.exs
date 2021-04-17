defmodule Skyscraper.Elevator.CarTest do
  alias Skyscraper.Elevator.Car
  use ExUnit.Case, async: true
  doctest Car

  describe "#build" do
    test "builds a Car struct with the given floor" do
      car = Car.build(floor: 5)
      assert %Car{} = car
      assert car.current_floor == 5
      assert car.moving_direction == nil
      assert car.step == nil
      assert car.step_duration == nil
    end
  end

  describe "#complete_step" do
    test "opens the doors when they were started to open" do
      car = %Car{step: :doors_opening} |> Car.complete_step()
      assert car.step == :doors_opened
    end

    test "starts to close the doors when they were opened" do
      car = %Car{step: :doors_opened} |> Car.complete_step()
      assert car.step == :doors_closing
    end

    test "ups one floor and keeps moving up when destination isn't reached" do
      car =
        %Car{current_floor: 4, step: :moving, moving_direction: :up, up_query: Prioqueue.new([6])}
        |> Car.complete_step()

      assert car.current_floor == 5
      assert car.step == :moving
      assert car.moving_direction == :up
    end

    test "ups one floor and starts to open doors when destination is reached by moving up" do
      car =
        %Car{current_floor: 4, step: :moving, moving_direction: :up, up_query: Prioqueue.new([5])}
        |> Car.complete_step()

      assert car.current_floor == 5
      assert car.step == :doors_opening
      assert car.up_query |> Prioqueue.to_list() == []
    end

    test "downs one floor and keeps moving down when destination isn't reached" do
      car =
        %Car{
          current_floor: 4,
          step: :moving,
          moving_direction: :down,
          down_query: Prioqueue.new([2])
        }
        |> Car.complete_step()

      assert car.current_floor == 3
      assert car.step == :moving
    end

    test "downs one floor and starts to open doors when destination is reached by moving down" do
      car =
        %Car{
          current_floor: 4,
          step: :moving,
          moving_direction: :down,
          down_query: Prioqueue.new([3])
        }
        |> Car.complete_step()

      assert car.current_floor == 3
      assert car.step == :doors_opening
      assert car.down_query |> Prioqueue.to_list() == []
    end

    test "becomes idle when there are no more destinations on closing doors" do
      car =
        %Car{
          step: :doors_closing,
          down_query: Prioqueue.new(),
          up_query: Prioqueue.new()
        }
        |> Car.complete_step()

      refute car.step
      refute car.moving_direction
    end

    test "starts to move up on closing doors when was moving up before stop and has upper destinations" do
      car =
        %Car{
          step: :doors_closing,
          moving_direction: :up,
          down_query: Prioqueue.new([3]),
          up_query: Prioqueue.new([5])
        }
        |> Car.complete_step()

      assert car.step == :moving
      assert car.moving_direction == :up
    end

    test "starts to move down on closing doors when was moving up before stop and doesn't have an upper destination, but has lower destinations" do
      car =
        %Car{
          step: :doors_closing,
          moving_direction: :up,
          down_query: Prioqueue.new([5]),
          up_query: Prioqueue.new()
        }
        |> Car.complete_step()

      assert car.step == :moving
      assert car.moving_direction == :down
    end

    test "starts to move down on closing doors when was moving down before stop and has lower destinations" do
      car =
        %Car{
          step: :doors_closing,
          moving_direction: :down,
          down_query: Prioqueue.new([3]),
          up_query: Prioqueue.new([5])
        }
        |> Car.complete_step()

      assert car.step == :moving
      assert car.moving_direction == :down
    end

    test "starts to move up on closing doors when was moving down before stop and doesn't have a lower destination, but has upper destinations" do
      car =
        %Car{
          step: :doors_closing,
          moving_direction: :down,
          down_query: Prioqueue.new(),
          up_query: Prioqueue.new([5])
        }
        |> Car.complete_step()

      assert car.step == :moving
      assert car.moving_direction == :up
    end
  end

  # describe "#build" do
  #   test "builds a Car struct with the given floor" do
  #     car = Car.build(floor: 5)
  #     assert %Car{} = car
  #     assert car.current_floor == 5
  #     assert car.moving_direction == nil
  #     assert car.step == nil
  #     assert car.step_duration == nil
  #   end
  # end
end
