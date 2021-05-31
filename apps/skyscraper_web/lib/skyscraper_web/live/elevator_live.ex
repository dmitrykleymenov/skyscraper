defmodule SkyscraperWeb.ElevatorLive do
  use SkyscraperWeb, :live_view
  alias SkyscraperOtp.Cleaner

  @impl true
  def render(assigns) do
    ~L"""
      <div class="elevator">
        <div class="number"><%= @elevator.id %></div>
        <div class="status"><%= @elevator.status %></div>
        <div class="current-floor"><%= @elevator.current_floor %></div>
        <div class="buttons">
          <%= for {floor, active} <- @elevator.floor_buttons do %>
            <span phx-click="elevator_button_push"
              phx-value-floor="<%= floor %>"
              class="car-button <%= if active, do: "active" %>">
                <%= floor %>
            </span>
          <% end %>
        </div>
        <br><br>
      </div>
    """
  end

  @impl true
  def mount(_, %{"elevator" => elevator}, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        SkyscraperOtp.PubSub,
        "building:#{elevator.building}:#{elevator.id}"
      )
    end

    {:ok, socket |> assign(elevator: elevator)}
  end

  @impl true
  def handle_event("elevator_button_push", %{"floor" => floor}, socket) do
    {floor, ""} = Integer.parse(floor)

    SkyscraperOtp.push_elevator_button(
      socket.assigns.elevator.building,
      socket.assigns.elevator.id,
      floor
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:elevator_state_changed, elevator}, socket) do
    Cleaner.touch(elevator.building)
    {:noreply, socket |> assign(:elevator, elevator)}
  end
end
