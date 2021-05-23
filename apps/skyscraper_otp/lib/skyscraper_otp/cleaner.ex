defmodule SkyscraperOtp.Cleaner do
  use GenServer
  @max_idle_seconds 10 * 60
  @period 10_000
  @moduledoc """
  Clener contains logic for destroying abandoned skyscrapers
  """

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def touch(arg) do
    building = Keyword.fetch!(arg, :building)
    registry = Keyword.get(arg, :registry, SkyscraperOtp.Registry)
    max_idle_seconds = Keyword.get(arg, :max_idle_seconds)

    GenServer.cast(__MODULE__, {:touch, {building, registry}, max_idle_seconds})
  end

  def destroy(building, registry \\ SkyscraperOtp.Registry) do
    GenServer.cast(__MODULE__, {:destroy, building, registry})
  end

  @impl true
  def init(arg) do
    :timer.send_interval(Keyword.get(arg, :period, @period), :check)
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:touch, building_info, max_idle_seconds}, skyscrapers) do
    skyscrapers =
      Map.update(
        skyscrapers,
        building_info,
        {DateTime.utc_now(), max_idle_seconds || @max_idle_seconds},
        fn {_, old_max_idle_seconds} ->
          {DateTime.utc_now(), max_idle_seconds || old_max_idle_seconds}
        end
      )

    {:noreply, skyscrapers}
  end

  @impl true
  def handle_cast({:destroy, building, registry}, skyscrapers) do
    case(Map.pop(skyscrapers, {building, registry})) do
      {nil, skyscrapers} ->
        {:noreply, skyscrapers}

      {_, skyscrapers} ->
        SkyscraperOtp.destroy(building, registry)
        {:noreply, skyscrapers}
    end
  end

  @impl true
  def handle_info(:check, skyscrapers) do
    skyscrapers
    |> Enum.filter(&abandoned?(&1))
    |> Enum.each(&destroy_skyscraper(&1))

    {:noreply, skyscrapers}
  end

  defp abandoned?({_skyscraper_info_, {last_touch_at, max_idle_seconds}}) do
    abandoned_at = DateTime.add(last_touch_at, max_idle_seconds)
    DateTime.compare(DateTime.utc_now(), abandoned_at) == :gt
  end

  defp destroy_skyscraper({{name, registry}, _abandon_info}) do
    destroy(name, registry)
  end
end
