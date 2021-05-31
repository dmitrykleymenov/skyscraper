defmodule SkyscraperOtp.CleanerTest do
  use ExUnit.Case, async: true
  alias SkyscraperOtp.Cleaner

  test "Builds a new cleaner" do
    assert Cleaner.build() == %{}
  end

  describe ".nullify_idling_time/3" do
    test "puts new building info to cleaner" do
      building_info = {"building_name", Registry}
      max_idle_seconds = 1000

      cleaner = Cleaner.nullify_idling_time(%{}, building_info, max_idle_seconds)
      assert cleaner |> Map.has_key?(building_info)

      assert_in_delta cleaner[building_info] |> elem(0) |> DateTime.to_unix(),
                      DateTime.utc_now() |> DateTime.to_unix(),
                      1

      assert cleaner[building_info] |> elem(1) == max_idle_seconds
    end

    test "sets up default idle time when idle time isn't provided" do
      cleaner = Cleaner.nullify_idling_time(%{}, {"building_name", Registry}, nil)

      assert cleaner[{"building_name", Registry}] |> elem(1) == 60 * 10
    end

    test "updates existed building info in cleaner" do
      building_info = {"building_name", Registry}
      max_idle_seconds = 1000
      datetime = DateTime.utc_now() |> DateTime.add(-100)

      cleaner = %{building_info => {datetime, 600}}

      cleaner = Cleaner.nullify_idling_time(cleaner, building_info, max_idle_seconds)

      assert_in_delta cleaner[building_info] |> elem(0) |> DateTime.to_unix(),
                      DateTime.utc_now() |> DateTime.to_unix(),
                      1

      assert cleaner[building_info] |> elem(1) == max_idle_seconds
    end

    test "keeps max idle time if non is provided" do
      building_info = {"building_name", Registry}
      max_idle_seconds = 1000

      cleaner =
        %{building_info => {DateTime.utc_now(), max_idle_seconds}}
        |> Cleaner.nullify_idling_time(building_info, nil)

      assert cleaner[building_info] |> elem(1) == max_idle_seconds
    end
  end

  describe ".destroy_building/2" do
    test "ignores if no buildings are with the key" do
      building_info = {"building_name", Registry}

      cleaner = %{building_info => {DateTime.utc_now(), 600}}

      {notifications, new_cleaner} =
        cleaner |> Cleaner.destroy_building({"another_buildng", Registry})

      assert cleaner == new_cleaner
      assert notifications == []
    end

    test "deletes from cleaner track and notify to destroy the building" do
      building_info = {"building_name", Registry}

      cleaner = %{building_info => {DateTime.utc_now(), 600}}

      {notifications, cleaner} = cleaner |> Cleaner.destroy_building(building_info)

      assert cleaner == %{}
      assert notifications == [{:destroy, building_info}]
    end
  end

  describe ".check/1" do
    test "deletes from cleaner track and notify to destroy the building" do
      cleaner = %{
        {"actual_1", Registry} => {DateTime.utc_now() |> DateTime.add(-500), 600},
        {"abandoned_1", Registry} => {DateTime.utc_now() |> DateTime.add(-500), 400},
        {"actual_2", Registry} => {DateTime.utc_now() |> DateTime.add(-50), 60},
        {"abandoned_2", Registry} => {DateTime.utc_now() |> DateTime.add(-50), 40}
      }

      {notifications, cleaner} = cleaner |> Cleaner.check()

      assert cleaner |> Map.keys() |> Enum.sort() == [
               {"actual_1", Registry},
               {"actual_2", Registry}
             ]

      assert notifications |> Enum.sort() == [
               {:destroy, {"abandoned_1", Registry}},
               {:destroy, {"abandoned_2", Registry}}
             ]
    end
  end
end
