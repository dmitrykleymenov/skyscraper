defmodule SkyscraperWeb.ConstructLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <div class="building-container">
      Building: <%= @dispatcher.building %>
    <div class="dispatcher">
      <%= for {{floor, direction}, active} <- @dispatcher.buttons do %>
        <button phx-click="hall_button_request"
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
        <div class="elevator">
          <div class="number"><%= elevator.id %></div>
          <div class="status"><%= elevator.status %></div>
          <div class="current-floor"><%= elevator.current_floor %></div>
          <div class="buttons">
            <%= for {floor, active} <- elevator.floor_buttons do %>
              <button phx-click="elevator_button_request"
                phx-value-floor="<%= floor %>"
                class="car-button <%= if active, do: "active" %>">
                  <%= floor %>
              </button>
            <% end %>
          </div>
          <br><br>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    name = Skyscraper.Repo.get!(Skyscraper.Buildings.Building, id).name
    skyscraper = SkyscraperOtp.get_state(name)

    socket = socket |> assign(skyscraper)

    # if connected?(socket) do
    #   {:ok, schedule_tick(socket)}
    # else
    {:ok, socket}
    # end
  end
end
