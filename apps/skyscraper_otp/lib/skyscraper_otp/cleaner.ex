defmodule SkyscraperOtp.Cleaner do
  @default_max_idle_seconds 10 * 60
  @moduledoc """
    Clener contains logic for detecting abandoned skyscrapers
  """

  @doc "Builds a new cleaner"
  def build(), do: %{}

  @doc """
    Renews last building action time to `now`
  """

  def nullify_idling_time(cleaner, building_info, nil) do
    Map.update(
      cleaner,
      building_info,
      {DateTime.utc_now(), @default_max_idle_seconds},
      fn {_, old_max_idle_seconds} ->
        {DateTime.utc_now(), old_max_idle_seconds}
      end
    )
  end

  def nullify_idling_time(cleaner, building_info, max_idle_seconds) do
    Map.put(cleaner, building_info, {DateTime.utc_now(), max_idle_seconds})
  end

  @doc """
    Clears a building based on the `building_info`
  """
  def destroy_building(cleaner, building_info) do
    case Map.pop(cleaner, building_info) do
      {nil, cleaner} -> {[], cleaner}
      {_, cleaner} -> {[{:destroy, building_info}], cleaner}
    end
  end

  def check(cleaner) do
    cleaner
    |> Enum.filter(&abandoned?(&1 |> elem(1)))
    |> Enum.reduce({[], cleaner}, &queue_to_destroy(&2, &1 |> elem(0)))
  end

  defp abandoned?({last_touch_at, max_idle_seconds}) do
    abandoned_at = DateTime.add(last_touch_at, max_idle_seconds)
    DateTime.compare(DateTime.utc_now(), abandoned_at) == :gt
  end

  defp queue_to_destroy({instructions, cleaner}, building_info) do
    {[{:destroy, building_info} | instructions], cleaner |> Map.delete(building_info)}
  end
end
