defmodule SkyscraperWeb.PageLive do
  use SkyscraperWeb, :live_view

  @impl true
  def render(assigns) do
    ~L"""
    <div class="skyscrapers-container">

      <%= if @skyscrapers |> Enum.empty?() do %>
        Currently no active elevators
      <% else %>
        <%= for skyscraper <- @skyscrapers do %>
          <div class="skyscraper">
            <%= link skyscraper, to: Routes.live_path(@socket, SkyscraperWeb.ConstructLive, skyscraper) %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(SkyscraperOtp.PubSub, "skyscrapers")

    {:ok, assign(socket, skyscrapers: SkyscraperOtp.list())}
  end

  @impl true
  def handle_info({:built, skyscraper}, socket) do
    {:noreply, socket |> assign(:skyscrapers, [skyscraper | socket.assigns.skyscrapers])}
  end

  @impl true
  def handle_info({:destroyed, skyscraper}, socket) do
    skyscrapers =
      socket.assigns.skyscrapers
      |> Enum.reject(fn s -> s == skyscraper end)

    {:noreply, socket |> assign(:skyscrapers, skyscrapers)}
  end
end
