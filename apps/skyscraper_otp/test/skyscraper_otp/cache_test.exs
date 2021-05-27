defmodule SkyscraperOtp.CacheTest do
  use ExUnit.Case, async: true

  test "creates ets tables for elevators and dispatchers on start", %{test: name} do
    {:ok, _} = start_supervised({SkyscraperOtp.Cache, name: name})

    refute :ets.whereis(:"#{name}_elevators") == :undefined
    refute :ets.whereis(:"#{name}_dispatchers") == :undefined
  end
end
