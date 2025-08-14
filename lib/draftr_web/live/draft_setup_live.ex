defmodule DraftrWeb.DraftSetupLive do
  use DraftrWeb, :live_view

  alias Draftr.DraftSession

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, league_name: "", members: [""], session_id: nil, link: nil)}
  end

  @impl true
  def handle_event("add_member", _params, socket) do
    {:noreply, update(socket, :members, fn members -> members ++ [""] end)}
  end

  def handle_event("update_league_name", %{"value" => value}, socket) do
    {:noreply, assign(socket, league_name: value)}
  end

  def handle_event("update_member", %{"idx" => idx, "value" => value}, socket) do
    idx = String.to_integer(idx)
    members = List.replace_at(socket.assigns.members, idx, value)
    {:noreply, assign(socket, members: members)}
  end

  def handle_event("start_draft", _params, socket) do
    members = Enum.filter(socket.assigns.members, &(&1 != ""))
    league_name = String.trim(socket.assigns.league_name)
    if league_name != "" and length(members) > 1 do
      session_id = DraftSession.create_session(league_name, members)
      link = Phoenix.VerifiedRoutes.live_path(DraftrWeb.Endpoint, DraftrWeb.Router, DraftrWeb.DraftLive, session_id)
      {:noreply, assign(socket, session_id: session_id, link: link)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-xl mx-auto mt-10 p-6 rounded shadow bg-base-200 text-base-content">
      <h1 class="text-3xl font-bold mb-4 text-primary">Create a New Draft</h1>
      <form phx-submit="start_draft">
        <div class="mb-4">
          <label class="block mb-1 font-semibold" for="league_name">League Name</label>
          <input id="league_name" name="league_name" type="text" value={@league_name} placeholder="Enter league name" class="w-full px-2 py-2 border border-base-300 rounded bg-base-100 text-base-content focus:outline-primary" phx-change="update_league_name" phx-value-value={@league_name} />
        </div>
        <label class="block mb-1 font-semibold">Members</label>
        <%= for {member, idx} <- Enum.with_index(@members) do %>
          <div class="mb-2 flex">
            <input type="text" name="member" value={member} placeholder="Member name" class="flex-1 px-2 py-2 border border-base-300 rounded bg-base-100 text-base-content focus:outline-primary" phx-change="update_member" phx-value-idx={idx} />
          </div>
        <% end %>
        <button type="button" phx-click="add_member" class="mt-2 px-3 py-1 bg-secondary text-secondary-content rounded">Add Member</button>
        <button type="submit" class="ml-2 px-4 py-2 bg-primary text-primary-content rounded">Generate Draft</button>
      </form>
      <%= if @link do %>
        <div class="mt-6 p-4 bg-success text-success-content rounded">
          <p class="mb-2 font-semibold">Share this link with your league members:</p>
          <a href={@link} class="text-info underline break-all"><%= @link %></a>
        </div>
      <% end %>
    </div>
    """
  end
end
