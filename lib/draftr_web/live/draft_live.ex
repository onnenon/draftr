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
        draft_title: session.draft_title,
        members: session.members,
        revealed: session.revealed,
        remaining: session.members -- session.revealed,
        viewers: session.viewers || 0,
        num_leagues: session.num_leagues,
        league_names: session.league_names || Enum.map(1..session.num_leagues, fn i -> "League #{i}" end),
        league_assignments: session.league_assignments || %{}
      )}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_event("next_pick", _params, socket) do
    revealed = DraftSession.reveal_next_pick(socket.assigns.session_id)
    # Calculate the index of the newly revealed member
    new_reveal_index = length(revealed) - 1

    # Trigger the reveal animation for the newly revealed member
    socket = push_event(socket, "reveal_pick", %{index: new_reveal_index})

    {:noreply, assign(socket, revealed: revealed, remaining: socket.assigns.members -- revealed)}
  end

  @impl true
  def handle_info({:draft_updated, session}, socket) do
    {:noreply, assign(socket,
      revealed: session.revealed,
      remaining: session.remaining,
      league_assignments: session.league_assignments
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
    <div class="w-full max-w-5xl mx-auto mt-4 sm:mt-10 p-5 sm:p-7 rounded-lg shadow-lg bg-base-200 text-base-content">
      <div class="flex flex-col sm:flex-row sm:justify-between sm:items-center mb-6 pb-4 border-b border-base-300">
        <h1 class="text-2xl sm:text-3xl font-bold text-primary mb-2 sm:mb-0"><%= @draft_title %></h1>
        <div class="flex items-center bg-base-100 px-3 py-2 rounded-lg shadow-sm">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-primary" viewBox="0 0 20 20" fill="currentColor">
            <path d="M10 12a2 2 0 100-4 2 2 0 000 4z" />
            <path fill-rule="evenodd" d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z" clip-rule="evenodd" />
          </svg>
          <span class="font-medium"><%= @viewers %> <%= if @viewers == 1, do: "viewer", else: "viewers" %></span>
        </div>
      </div>

      <div class="mb-6 p-4 bg-base-300 rounded-lg shadow-inner">
        <h2 class="text-lg mb-3 font-semibold">League Members (<%= length(@members) %> total):</h2>
        <ul class="flex flex-wrap gap-2">
          <%= for member <- @members do %>
            <li class={"py-1.5 px-3 rounded-full #{if Map.has_key?(@league_assignments, member), do: "bg-success text-success-content", else: "bg-base-100 border border-base-300"} shadow-sm"}>
              <%= member %>
            </li>
          <% end %>
        </ul>
      </div>

      <div class="mb-4 p-4 bg-base-300 rounded-lg shadow-inner">
        <div class="flex justify-between items-center">
          <h2 class="text-lg font-semibold">Draft Progress:</h2>
          <div class="text-sm font-medium">
            <%= length(@revealed) %> of <%= length(@members) %> picks revealed
          </div>
        </div>
        <div class="w-full bg-base-100 rounded-full h-2.5 mt-2">
          <div class="bg-primary h-2.5 rounded-full" style={"width: #{if length(@members) > 0, do: length(@revealed) / length(@members) * 100, else: 0}%"}></div>
        </div>
      </div>

      <div id="draft-container" phx-hook="Reveal" class="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">
        <%= for league_num <- 1..@num_leagues do %>
          <div class="bg-base-300 rounded-lg p-4 shadow-md">
            <h3 class="text-3xl font-bold text-secondary mb-4 pb-2 border-b border-base-content/20">
              <%= Enum.at(@league_names, league_num - 1, "League #{league_num}") %>
            </h3>

            <ol class="space-y-3 pl-2">
              <%
                # Get the number of rounds for this league
                total_members = length(@members)
                rounds_per_league = div(total_members + @num_leagues - 1, @num_leagues)
              %>

              <%= for round <- 1..rounds_per_league do %>
                <%
                  # Calculate the overall index for this round and league
                  index = (round - 1) * @num_leagues + (league_num - 1)
                  is_revealed = index < length(@revealed)
                  member_name = if is_revealed, do: Enum.at(@revealed, index), else: nil
                %>

                <li class="font-medium text-lg">
                  <div class="flex items-center">
                    <span class="mr-2 font-semibold w-6 text-right"><%= round %>.</span>
                    <%= if is_revealed do %>
                      <div
                        data-row-index={index}
                        class="transition-all duration-500 bg-base-100 py-1.5 px-3 rounded-md shadow-sm text-primary font-semibold opacity-100 flex-1"
                      >
                        <%= member_name %>
                      </div>
                    <% else %>
                      <div class="py-1.5 px-3 rounded-md border border-dashed border-base-content/30 text-base-content/50 italic flex-1">
                        Empty
                      </div>
                    <% end %>
                  </div>
                </li>
              <% end %>
            </ol>
          </div>
        <% end %>
      </div>

      <div class="flex justify-center mt-6">
        <%= if length(@revealed) < length(@members) do %>
          <button phx-click="next_pick" class="mt-4 px-6 py-3 bg-primary text-primary-content rounded-lg shadow-md font-semibold text-lg hover:translate-y-[-2px] hover:shadow-lg transition-all duration-300">
            Reveal Next Pick
          </button>
        <% else %>
          <div class="mt-4 px-6 py-4 bg-success text-success-content rounded-lg shadow-md font-semibold text-lg flex items-center justify-center min-h-[60px]">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 inline-block mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
            Draft complete! All picks have been revealed.
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
