defmodule DraftrWeb.DraftLive do
  use DraftrWeb, :live_view

  alias Draftr.DraftSession

  @impl true
  def mount(%{"id" => session_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to updates for this draft session
      Phoenix.PubSub.subscribe(Draftr.PubSub, "draft:#{session_id}")
      # Increment the viewer count
      DraftSession.increment_viewers(session_id)
    end

    session = DraftSession.get_session(session_id)
    if session do
      {:ok, assign(socket,
        session_id: session_id,
        league_name: session.league_name,
        members: session.members,
        revealed: session.revealed,
        remaining: session.members -- session.revealed,
        viewers: session.viewers || 0
      )}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_event("next_pick", _params, socket) do
    revealed = DraftSession.reveal_next_pick(socket.assigns.session_id)
    {:noreply, assign(socket, revealed: revealed, remaining: socket.assigns.members -- revealed)}
  end

  @impl true
  def handle_info({:draft_updated, session}, socket) do
    {:noreply, assign(socket,
      revealed: session.revealed,
      remaining: session.remaining
    )}
  end

  @impl true
  def handle_info({:viewers_updated, count}, socket) do
    {:noreply, assign(socket, viewers: count)}
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:session_id] do
      DraftSession.decrement_viewers(socket.assigns.session_id)
    end
    :ok
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full max-w-xl mx-auto mt-4 sm:mt-10 p-4 sm:p-6 rounded shadow bg-base-200 text-base-content">
      <div class="flex justify-between items-center mb-4">
        <h1 class="text-2xl sm:text-3xl font-bold text-primary"><%= @league_name %> Draft</h1>
        <div class="flex items-center bg-base-100 px-2 py-1 rounded">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1 text-primary" viewBox="0 0 20 20" fill="currentColor">
            <path d="M10 12a2 2 0 100-4 2 2 0 000 4z" />
            <path fill-rule="evenodd" d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z" clip-rule="evenodd" />
          </svg>
          <span class="text-sm font-medium"><%= @viewers %> <%= if @viewers == 1, do: "viewer", else: "viewers" %></span>
        </div>
      </div>
      <h2 class="text-lg mb-2 font-semibold">Members:</h2>
      <ul class="mb-4 flex flex-wrap gap-2">
        <%= for member <- @members do %>
          <li class="py-1 px-2 rounded bg-base-100 border border-base-300"><%= member %></li>
        <% end %>
      </ul>
      <h2 class="text-xl mb-2 font-semibold text-success">Draft Order:</h2>
      <ol class="list-decimal ml-6 mb-4">
        <%= for member <- @revealed do %>
          <li class="py-1 text-lg font-medium"><%= member %></li>
        <% end %>
      </ol>
      <%= if length(@revealed) < length(@members) do %>
        <button phx-click="next_pick" class="px-4 py-2 bg-primary text-primary-content rounded">Next</button>
      <% else %>
        <div class="mt-4 p-2 bg-success text-success-content rounded font-semibold">Draft complete!</div>
      <% end %>
    </div>
    """
  end
end
