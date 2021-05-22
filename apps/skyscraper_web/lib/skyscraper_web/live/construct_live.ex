defmodule SkyscraperWeb.ConstructLive do
  use SkyscraperWeb, :live_view

  @impl true
  def render(assigns) do
    ~L"""
    <div class="building-container">
      Building: <%= @dispatcher.building %>
    <div class="dispatcher">
      <%= for {{floor, direction}, active} <- @dispatcher.buttons do %>
        <span phx-click="hall_button_push"
                phx-value-floor="<%= floor %>"
                phx-value-direction="<%= direction %>"
                class="hall-button <%= if active, do: "active" %>">
          <%= "#{floor}-#{direction}" %>
      </span>
      <% end %>
    </div>
    <hr>
    <div class="elevators">
      <%= for elevator <- @elevators do %>
        <%= live_render(@socket , SkyscraperWeb.ElevatorLive, id: "elevator-#{elevator.id}", session: %{"elevator" => elevator}) %>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => name}, _session, socket) do
    assigns =
      name
      |> SkyscraperOtp.get_state()
      |> Map.put(:building, name)

    socket = socket |> assign(assigns)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(SkyscraperOtp.PubSub, "building:#{name}")
      Phoenix.PubSub.subscribe(SkyscraperOtp.PubSub, "skyscrapers")
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("hall_button_push", %{"floor" => floor, "direction" => direction}, socket) do
    {floor, ""} = Integer.parse(floor)
    direction = String.to_existing_atom(direction)

    SkyscraperOtp.push_hall_button(socket.assigns.building, {floor, direction})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:dispatcher_state_changed, dispatcher}, socket) do
    {:noreply, socket |> assign(:dispatcher, dispatcher)}
  end

  @impl true
  def handle_info({:skyscraper_built, _skyscraper}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:skyscraper_destroyed, skyscraper},
        %{assigns: %{building: skyscraper}} = socket
      ) do
    {:noreply, socket |> push_redirect(to: Routes.page_path(socket, :index))}
  end

  @impl true
  def handle_info({:skyscraper_destroyed, _skyscraper}, socket) do
    {:noreply, socket}
  end
end
