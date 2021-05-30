defmodule SkyscraperOtp.Cleaner.Server do
  use GenServer
  alias SkyscraperOtp.Cleaner
  @period 10_000
  @moduledoc """
    OTP Server for `Cleaner`
  """

  @doc false
  def start_link(arg) do
    name = arg |> Keyword.get(:name, __MODULE__)

    GenServer.start_link(__MODULE__, name, name: name)
  end

  @doc """
    Tells server about new action in building
  """
  def touch(arg) do
    building = Keyword.fetch!(arg, :building)
    registry = Keyword.get(arg, :registry, SkyscraperOtp.Registry)
    max_idle_seconds = Keyword.get(arg, :max_idle_seconds)

    GenServer.cast(__MODULE__, {:touch, {building, registry}, max_idle_seconds})
  end

  @doc """
    Calls `SkyScraper.destroy` with `building`
  """
  def destroy(building, registry \\ SkyscraperOtp.Registry) do
    GenServer.cast(__MODULE__, {:destroy, {building, registry}})
  end

  @impl true
  def init(arg) do
    :timer.send_interval(Keyword.get(arg, :period, @period), :check)
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:touch, building_info, max_idle_seconds}, cleaner) do
    {:noreply, cleaner |> Cleaner.renew_idle_time(building_info, max_idle_seconds)}
  end

  @impl true
  def handle_cast({:destroy, building_info}, cleaner) do
    {instructions, cleaner} = cleaner |> Cleaner.destroy(building_info)
    instructions |> Enum.each(&run/1)

    {:noreply, cleaner}
  end

  @impl true
  def handle_info(:check, cleaner) do
    {instructions, cleaner} = cleaner |> Cleaner.check()
    instructions |> Enum.each(&run/1)

    {:noreply, cleaner}
  end

  defp run({:destroy, {building, registry}}) do
    SkyscraperOtp.destroy(building, registry)
  end
end
