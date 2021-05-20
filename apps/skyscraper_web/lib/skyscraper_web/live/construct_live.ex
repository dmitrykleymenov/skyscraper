defmodule SkyscraperWeb.ConstructLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div class="building-container">
      Building: <%= @dispatcher.building %>
    <div class="dispatcher">
      <%= for {{floor, direction}, active} <- @dispatcher.buttons do %>
        <button phx-click="hall_button_push"
                phx-value-floor="<%= floor %>"
                phx-value-direction="<%= direction %>"
                class="hall-button <%= if active, do: "active" %>">
          <%= "#{floor} - #{direction}" %>
      </button>
      <% end %>
    </div>
    <hr>
    <div class="elevators">
      <%= for elevator <- @elevators do %>
        <%= live_render(@socket , SkyscraperWeb.ElevatorLive, id: elevator.id, session: %{"elevator" => elevator}) %>
      <% end %>
    </div>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    # Refactor to Kernel.then/1 on Elixir 1.12
    name = Skyscraper.Repo.get!(Skyscraper.Buildings.Building, id).name

    assigns =
      name
      |> SkyscraperOtp.get_state()
      |> Map.put(:building, name)

    socket = socket |> assign(assigns)

    # if connected?(socket) do
    #   Phoenix.PubSub.subscribe(SkyscraperOtp.PubSub, "building:#{name}")
    # end

    {:ok, socket}
  end

  def handle_event("hall_button_push", %{"floor" => floor, "direction" => direction}, socket) do
    {floor, ""} = Integer.parse(floor)
    direction = String.to_existing_atom(direction)

    SkyscraperOtp.push_hall_button(socket.assigns.building, {floor, direction})
    {:noreply, socket}
  end

  def handle_event("elevator_button_push", %{"floor" => floor, "id" => id}, socket) do
    {floor, ""} = Integer.parse(floor)
    {id, ""} = Integer.parse(id)

    SkyscraperOtp.push_elevator_button(socket.assigns.building, id, floor)
    {:noreply, socket}
  end
end
