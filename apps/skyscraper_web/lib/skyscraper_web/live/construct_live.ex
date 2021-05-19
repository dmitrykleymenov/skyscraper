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

  def handle_info(:tick, socket) do
    new_socket =
      socket
      |> game_loop()
      |> schedule_tick()

    {:noreply, new_socket}
  end

  def handle_event("update_settings", %{"width" => width, "tick" => tick}, socket) do
    {width, ""} = Integer.parse(width)
    {tick, ""} = Integer.parse(tick)

    new_socket =
      socket
      |> assign(width: width)
      |> update_tick(tick)
      |> build_board()

    {:noreply, new_socket}
  end

  def handle_event("keydown", payload, socket) do
    {:noreply, turn(socket, payload["code"])}
  end

  defp update_tick(socket, tick) when tick >= 50 and tick <= 1000 do
    assign(socket, :tick, tick)
  end

  defp turn(socket, "ArrowLeft"), do: go(socket, :left)
  defp turn(socket, "ArrowDown"), do: go(socket, :down)
  defp turn(socket, "ArrowUp"), do: go(socket, :up)
  defp turn(socket, "ArrowRight"), do: go(socket, :right)
  defp turn(socket, _), do: socket

  defp go(%{assigns: %{heading: heading}} = socket, heading), do: socket

  defp go(socket, heading) do
    socket
    |> assign(rotation: Map.fetch!(@rotation, heading))
    |> assign(heading: heading)
  end

  def game_loop(socket) do
    socket
    |> advance()
  end

  defp schedule_tick(socket) do
    Process.send_after(self(), :tick, socket.assigns.tick)
    socket
  end

  defp build_board(socket) do
    width = socket.assigns.width

    {_, blocks} =
      Enum.reduce(@board, {0, %{}}, fn row, {y_index, acc} ->
        {_, blocks} =
          Enum.reduce(row, {0, acc}, fn
            "X", {x_index, acc} ->
              {x_index + 1,
               Map.put(acc, {y_index, x_index}, %{
                 type: :wall,
                 x: x_index * width,
                 y: y_index * width,
                 width: width
               })}

            "0", {x_index, acc} ->
              {x_index + 1,
               Map.put(acc, {y_index, x_index}, %{
                 type: :empty,
                 x: x_index * width,
                 y: y_index * width,
                 width: width
               })}
          end)

        {y_index + 1, blocks}
      end)

    assign(socket, :blocks, blocks)
  end

  defp advance(socket) do
    %{width: width, heading: heading, blocks: blocks} = socket.assigns
    col_before = socket.assigns.col
    row_before = socket.assigns.row
    maybe_row = row(row_before, heading)
    maybe_col = col(col_before, heading)

    {row, col} =
      case block(maybe_row, maybe_col, blocks) do
        :wall -> {row_before, col_before}
        :empty -> {maybe_row, maybe_col}
      end

    socket
    |> assign(:row, row)
    |> assign(:col, col)
    |> assign(:x, col * width)
    |> assign(:y, row * width)
  end

  defp col(val, :left) when val - 1 >= 1, do: val - 1
  defp col(val, :right) when val + 1 < @board_cols - 1, do: val + 1
  defp col(val, _), do: val

  defp row(val, :up) when val - 1 >= 1, do: val - 1
  defp row(val, :down) when val + 1 < @board_rows - 1, do: val + 1
  defp row(val, _), do: val

  def block(row, col, blocks) do
    Map.fetch!(blocks, {row, col}).type
  end
end
