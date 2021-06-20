defmodule SkyscraperWeb.PageLive do
  use SkyscraperWeb, :live_view

  @impl true
  def render(assigns) do
    ~L"""
      <div class="container">
        <%= if @skyscrapers |> Enum.empty?() do %>
          <span class="text">Currently no active elevators</span>
        <% else %>
          <ul class="list">
            <%= for skyscraper <- @skyscrapers do %>
              <li class="list__item">
                <%= link skyscraper, to: Routes.live_path(@socket, SkyscraperWeb.ConstructLive, skyscraper), class: "list__link" %>
              </li>
            <% end %>
          </ul>
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
  def handle_info({:skyscraper_built, skyscraper}, socket) do
    {:noreply, socket |> assign(:skyscrapers, [skyscraper | socket.assigns.skyscrapers])}
  end

  @impl true
  def handle_info({:skyscraper_destroyed, skyscraper}, socket) do
    skyscrapers =
      socket.assigns.skyscrapers
      |> Enum.reject(fn s -> s == skyscraper end)

    {:noreply, socket |> assign(:skyscrapers, skyscrapers)}
  end
end
