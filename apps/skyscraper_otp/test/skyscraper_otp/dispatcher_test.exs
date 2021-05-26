defmodule SkyscraperOtp.DispatcherTest do
  alias SkyscraperOtp.Dispatcher
  use ExUnit.Case, async: true

  setup do
    %{dispatcher: Dispatcher.build(elevator_ids: [1, 2, 3], floors: 1..40 |> Enum.to_list())}
  end

  test "builds a Dispatcher struct with the given params" do
    dispatcher = Dispatcher.build(elevator_ids: [1, 2], floors: [4, 5, 6])
    assert %Dispatcher{} = dispatcher
    assert dispatcher.queue |> Enum.empty?()
    assert dispatcher.buttons == [{4, :up}, {5, :down}, {5, :up}, {6, :down}]
  end

  test "shows all active buttons" do
    assert %Dispatcher{queue: [{5, :up}, {7, :down}]}
           |> Dispatcher.active_buttons() == [{5, :up}, {7, :down}]
  end

  test "returns all possible buttons" do
    assert %Dispatcher{buttons: [{1, :up}, {2, :down}, {2, :up}, {3, :down}]}
           |> Dispatcher.available_buttons() == [{1, :up}, {2, :down}, {2, :up}, {3, :down}]
  end

  test "returns elevator ids", %{dispatcher: dispatcher} do
    assert dispatcher |> Dispatcher.elevator_ids() == [1, 2, 3]
  end

  describe ".push_button/3" do
    test "just adds request to query when nobody can handle it", %{dispatcher: dispatcher} do
      {instructions, dispatcher} =
        dispatcher |> Dispatcher.push_button({5, :down}, %{1 => nil, 2 => nil, 3 => nil})

      assert instructions |> Enum.empty?()
      assert dispatcher |> Dispatcher.active_buttons() == [{5, :down}]
    end

    test "propose to handle the request to elevator with possible handle time", %{
      dispatcher: dispatcher
    } do
      {instructions, dispatcher} =
        dispatcher |> Dispatcher.push_button({5, :down}, %{1 => nil, 2 => 5000, 3 => nil})

      assert instructions == [{:propose_to_handle, 2, [{{5, :down}, nil}]}]
      assert dispatcher |> Dispatcher.active_buttons() == [{5, :down}]
    end

    test "propose to handle the request to elevator with minimal handle time", %{
      dispatcher: dispatcher
    } do
      {instructions, dispatcher} =
        dispatcher |> Dispatcher.push_button({5, :down}, %{1 => 7000, 2 => 5000, 3 => nil})

      assert instructions == [{:propose_to_handle, 2, [{{5, :down}, nil}]}]
      assert dispatcher |> Dispatcher.active_buttons() == [{5, :down}]
    end
  end

  describe ".set_time_to_destination/3" do
    test "updates destination info for appropriate elevator", %{dispatcher: dispatcher} do
      {instructions, dispatcher} =
        dispatcher |> Dispatcher.set_time_to_destination(1, {{7, :up}, 4000})

      assert instructions |> Enum.empty?()
      assert dispatcher.elevators[1] == {{7, :up}, 4000}
    end

    test "updates destination info, send canceling instruction and clears destination info for less efficient elevator",
         %{
           dispatcher: dispatcher
         } do
      {instructions, dispatcher} =
        dispatcher
        |> Map.put(:elevators, %{1 => nil, 2 => {{7, :up}, 6000}, 3 => nil})
        |> Dispatcher.set_time_to_destination(1, {{7, :up}, 4000})

      assert instructions == [{:cancel_request, 2, {7, :up}}]
      assert dispatcher.elevators[1] == {{7, :up}, 4000}
      assert dispatcher.elevators[2] == nil
    end
  end

  describe ".request_handled/3" do
    test "clears destination info for the elevator and removes request from queue", %{
      dispatcher: dispatcher
    } do
      dispatcher =
        dispatcher
        |> Map.put(:queue, [{7, :up}, {3, :down}])
        |> Map.put(:elevators, %{1 => nil, 2 => nil, 3 => {{7, :up}, 1000}})
        |> Dispatcher.request_handled(3, {7, :up})

      assert dispatcher.elevators == %{1 => nil, 2 => nil, 3 => nil}
      assert dispatcher |> Dispatcher.active_buttons() == [{3, :down}]
    end
  end

  describe ".prpose_requests/2" do
    setup %{dispatcher: dispatcher} do
      %{dispatcher: %{dispatcher | queue: [{5, :up}, {6, :down}, {7, :up}]}}
    end

    test "adds all queued requests to proposal instruction", %{dispatcher: dispatcher} do
      {instructions, new_dispatcher} = dispatcher |> Dispatcher.propose_requests(1)

      assert dispatcher == new_dispatcher

      assert instructions == [
               {:propose_to_handle, 1, [{{5, :up}, nil}, {{6, :down}, nil}, {{7, :up}, nil}]}
             ]
    end

    test "adds all queued requests with current handle time to proposal instruction", %{
      dispatcher: dispatcher
    } do
      dispatcher =
        dispatcher
        |> Map.put(:elevators, %{1 => nil, 2 => {{5, :up}, 5000}, 3 => {{7, :up}, 6000}})

      {instructions, new_dispatcher} =
        dispatcher
        |> Dispatcher.propose_requests(1)

      assert dispatcher == new_dispatcher

      assert instructions == [
               {:propose_to_handle, 1, [{{5, :up}, 5000}, {{6, :down}, nil}, {{7, :up}, 6000}]}
             ]
    end
  end

  describe ".button_active?/2" do
    test "truthy when the button is in queue" do
      assert %Dispatcher{queue: [{5, :up}]} |> Dispatcher.button_active?({5, :up})
    end

    test "falsey when button isn't in queue" do
      refute %Dispatcher{queue: [{5, :up}]} |> Dispatcher.button_active?({6, :up})
    end
  end
end
