defmodule SkyscraperOtp.CleanerTest do
  use ExUnit.Case, async: true
  alias SkyscraperOtp.Cache

  test "checks on abandoned skycrapers", %{test: name} do
    assert :ets.whereis(:"#{name}_elevators") == :undefined
    assert :ets.whereis(:"#{name}_dispatchers") == :undefined

    {:ok, _} = start_supervised({Cache, name: name})

    refute :ets.whereis(:"#{name}_elevators") == :undefined
    refute :ets.whereis(:"#{name}_dispatchers") == :undefined
  end

  test "adds dispatcher to cache", %{test: name} do
    {:ok, cache} = start_supervised({Cache, name: name})
    assert :ets.lookup(:"#{name}_dispatchers", "building_name") == []
    Cache.update_dispatcher("building_name", "some_dispatcher", cache)
    Process.sleep(1)

    assert :ets.lookup(:"#{name}_dispatchers", "building_name") == [
             {"building_name", "some_dispatcher"}
           ]
  end

  test "gets dispatcher from cache", %{test: name} do
    {:ok, cache} = start_supervised({Cache, name: name})

    refute Cache.get_dispatcher("building_name", name)
    Cache.update_dispatcher("building_name", "some_dispatcher", cache)
    Process.sleep(1)

    assert Cache.get_dispatcher("building_name", name) == "some_dispatcher"
  end

  test "adds elevator to cache", %{test: name} do
    {:ok, cache} = start_supervised({Cache, name: name})
    assert :ets.lookup(:"#{name}_elevators", {"building_name", "id"}) == []
    Cache.update_elevator("building_name", "id", "some_elevator", cache)
    Process.sleep(1)

    assert :ets.lookup(:"#{name}_elevators", {"building_name", "id"}) == [
             {{"building_name", "id"}, "some_elevator"}
           ]
  end

  test "gets elevator from cache", %{test: name} do
    {:ok, cache} = start_supervised({Cache, name: name})

    refute Cache.get_elevator("building_name", "id", name)
    Cache.update_elevator("building_name", "id", "some_elevator", cache)
    Process.sleep(1)

    assert Cache.get_elevator("building_name", "id", name) == "some_elevator"
  end
end
