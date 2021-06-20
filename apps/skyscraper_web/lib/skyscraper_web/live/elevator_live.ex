defmodule SkyscraperWeb.ElevatorLive do
  use SkyscraperWeb, :live_view
  alias SkyscraperOtp.Cleaner.Server, as: Cleaner

  @impl true
  def render(assigns) do
    ~L"""
      <div class="elevator <%= @elevator.status %>">
        <div class="elevator__header">
          <div class="elevator__name"><%= @elevator.id %></div>
          <div class="elevator__screen">
            <span><%= @elevator.current_floor %></span>
            <div class="elevator__direction"></div>
          </div>
          <div class="elevator__doors"></div>
        </div>
        <div class="elevator__body">
          <div class="elevator__btns">
            <%= for {floor, active} <- @elevator.floor_buttons do %>
              <button type="button"
                      class="elevator__btn<%= if active, do: " elevator__btn--active" %>"
                      phx-click="elevator_button_push"
                      phx-value-floor="<%= floor %>"
              ><%= floor %></button>
            <% end %>
          </div>
        </div>
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
