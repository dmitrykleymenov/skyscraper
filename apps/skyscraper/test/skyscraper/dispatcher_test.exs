defmodule Skyscraper.DispatcherTest do
  alias Skyscraper.Dispatcher
  use ExUnit.Case, async: true

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

  test "returns elevator ids" do
    assert %Dispatcher{elevators: %{1 => nil, 2 => nil}} |> Dispatcher.elevator_ids() == [1, 2]
  end

  describe ".push_button/3" do
    setup do
      %{dispatcher: Dispatcher.build(elevator_ids: [1, 2, 3], floors: 1..40 |> Enum.to_list())}
    end

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
  end

  describe ".button_active?/2" do
    test "truthy when button in queue" do
      assert %Dispatcher{queue: [{5, :up}]} |> Dispatcher.button_active?({5, :up})
    end

    test "falsey when button isn't in queue" do
      refute %Dispatcher{queue: [{5, :up}]} |> Dispatcher.button_active?({6, :up})
    end
  end
end
