defmodule SkyscraperWeb.ConstructLive do
  use SkyscraperWeb, :live_view

  @impl true
  def render(assigns) do
    ~L"""
      <div class="main__container container">
        <div class="main__left">
          <button class="main__floors-btn">Show floors</button>
          <div class="floors">
            <div class="floors__header">
              <h2 class="floors__title">Floors</h2>
              <button class="floors__close icon-close"></button>
            </div>
            <div class="floors__body">
              <ul class="floors__list">
                <li class="floors__item">
                  <span class="floors__label">1</span>
                  <%= for {{floor, direction}, active} <- @dispatcher.buttons do %>
                    <%= if direction == :down do %>
                      <li class="floors__item">
                        <span class="floors__label"><%= floor %></span>
                        <button phx-click="hall_button_push"
                                phx-value-floor="<%= floor %>"
                                phx-value-direction="<%= direction %>"
                                class="floors__btn icon-down<%= if active, do: "floors__btn--active"%>"
                        ></button>
                    <% else %>
                      <button phx-click="hall_button_push"
                              phx-value-floor="<%= floor %>"
                              phx-value-direction="<%= direction %>"

                              class="floors__btn icon-up<%= if active, do: "floors__btn--active"%>"
                      ></button>
                      </li>
                    <% end %>
                  <% end %>
                </li>
              </ul>
            </div>
          </div>
        </div>
        <div class="main__right">
          <h2 class="main__elevators-title">Elevators(<%= @dispatcher.building %>)</h2>
          <div class="main__elevators">
            <%= for elevator <- @elevators do %>
              <%= live_render(@socket , SkyscraperWeb.ElevatorLive, id: "elevator-#{elevator.id}", session: %{"elevator" => elevator}) %>
            <% end %>
          </div>
        </div>
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
