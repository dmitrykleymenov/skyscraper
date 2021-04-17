defmodule Skyscraper.Elevator.CarTest do
  alias Skyscraper.Elevator.Car
  use ExUnit.Case
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
    test "changes doors opening step to doors opened one" do
      car = %Car{step: :doors_opening} |> Car.complete_step()
      assert car.step == :doors_opened
    end

    test "changes doors opened step to doors closing one" do
      car = %Car{step: :doors_opened} |> Car.complete_step()
      assert car.step == :doors_closing
    end

    test "lifts up one floor and keeps moving step when direction - up and destination floor hasn't stop point" do
      car =
        %Car{current_floor: 4, step: :moving, moving_direction: :up, up_query: Prioqueue.new([6])}
        |> Car.complete_step()

      assert car.current_floor == 5
      assert car.step == :moving
    end

    test "lifts up one floor and starts to open doors when step: moving, direction: up and destination floor has stop point" do
      car =
        %Car{current_floor: 4, step: :moving, moving_direction: :up, up_query: Prioqueue.new([5])}
        |> Car.complete_step()

      assert car.current_floor == 5
      assert car.step == :doors_opening
      assert car.up_query |> Prioqueue.to_list() == []
    end

    test "lifts down one floor and keeps moving step when direction - down and destination floor hasn't stop point" do
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

    test "lifts down one floor and starts to open doors when step: moving, direction: down and destination floor has stop point" do
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

    test "becomes idle when step: doors closing and both queries are empty" do
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

    test "starts to move up when has upper destinations, step is doors closing and was moving up" do
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

    test "starts to move down when doesn't have upper destinations, but has lower destinations, step is doors closing and was moving up" do
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

    test "starts to move down when has lower destinations, step is doors closing and was moving down" do
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

    test "starts to move down when doesn't have lower destinations, but has upper destinations, step is doors closing and was moving down" do
      car =
        %Car{
          step: :doors_closing,
          moving_direction: :up,
          down_query: Prioqueue.new(),
          up_query: Prioqueue.new([5])
        }
        |> Car.complete_step()

      assert car.step == :moving
      assert car.moving_direction == :up
    end
  end
end
