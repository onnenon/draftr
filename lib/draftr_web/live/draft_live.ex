defmodule DraftrWeb.DraftLive do
  use DraftrWeb, :live_view

  alias Draftr.DraftSession

  @impl true
  def mount(%{"id" => session_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to updates for this draft session
      Phoenix.PubSub.subscribe(Draftr.PubSub, "draft:#{session_id}")
    end

    session = DraftSession.get_session(session_id)
    if session do
      {:ok, assign(socket,
        session_id: session_id,
        league_name: session.league_name,
        members: session.members,
        revealed: session.revealed,
        remaining: session.remaining
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
  def render(assigns) do
    ~H"""
    <div class="max-w-xl mx-auto mt-10 p-6 rounded shadow bg-base-200 text-base-content">
      <h1 class="text-3xl font-bold mb-4 text-primary"><%= @league_name %> Draft</h1>
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
