defmodule DraftrWeb.DraftSetupLive do
  use DraftrWeb, :live_view

  alias Draftr.DraftSession

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, 
      draft_title: "", 
      members: [""], 
      session_id: nil, 
      link: nil, 
      full_url: nil, 
      num_leagues: 1,
      league_names: %{1 => "League 1"}
    )}
  end

  @impl true
  def handle_event("add_member", _params, socket) do
    # Check if there's already an empty member field
    has_empty_field = Enum.any?(socket.assigns.members, fn member -> member == "" end)

    if has_empty_field do
      # If there's already an empty field, don't add another one
      # Instead, flash a message to use the existing empty field
      socket = put_flash(socket, :info, "Please use the existing empty field before adding a new one")
      # Auto-dismiss the flash message after 3 seconds
      Process.send_after(self(), :clear_flash, 3000)
      # Trigger animation to highlight empty fields
      socket = push_event(socket, "highlight_empty", %{})
      {:noreply, socket}
    else
      # Add a new member field
      updated_members = socket.assigns.members ++ [""]
      index = length(updated_members) - 1
      socket = assign(socket, members: updated_members)
      # Send event to trigger animation
      socket = push_event(socket, "item_added", %{index: index})
      {:noreply, socket}
    end
  end

  def handle_event("remove_member", %{"index" => index}, socket) do
    index = String.to_integer(index)
    # First send animation event before removing the item
    socket = push_event(socket, "item_removed", %{index: index})

    # Then remove the item after a delay to allow animation to play
    Process.send_after(self(), {:remove_member, index}, 300)
    {:noreply, socket}
  end

  def handle_event("form_change", params, socket) do
    draft_title = params["draft_title"] || ""

    # Get the number of leagues (default to 1)
    num_leagues = case params["num_leagues"] do
      nil -> 1
      "" -> 1
      val ->
        case Integer.parse(val) do
          {num, _} when num > 0 -> num
          _ -> 1
        end
    end

    # Get all league names
    league_names = Enum.reduce(1..num_leagues, %{}, fn idx, acc ->
      name = params["league_name_#{idx}"] || "League #{idx}"
      Map.put(acc, idx, name)
    end)

    # Get all member inputs
    members = socket.assigns.members
    |> Enum.with_index()
    |> Enum.map(fn {_member, idx} ->
      params["member_#{idx}"] || ""
    end)

    {:noreply, assign(socket, draft_title: draft_title, members: members, num_leagues: num_leagues, league_names: league_names)}
  end

  def handle_event("start_draft", params, socket) do
    require Logger
    Logger.info("Start draft event triggered with params: #{inspect(params)}")

    members = Enum.filter(socket.assigns.members, &(&1 != ""))
    draft_title = String.trim(socket.assigns.draft_title)
    num_leagues = socket.assigns.num_leagues
    league_names = Map.values(socket.assigns.league_names)

    Logger.info("Draft title: #{inspect(draft_title)}, Members: #{inspect(members)}, Num leagues: #{num_leagues}, League names: #{inspect(league_names)}")

    min_members_per_league = 2
    total_min_members = min_members_per_league * num_leagues

    if draft_title != "" and length(members) >= total_min_members do
      session_id = DraftSession.create_session(draft_title, members, num_leagues, league_names)
      Logger.info("Session created with ID: #{inspect(session_id)}")

      # Generate the path
      path = ~p"/draft/#{session_id}"

      # Generate the full URL based on the endpoint configuration
      url = DraftrWeb.Endpoint.url()
      full_url = "#{url}#{path}"

      {:noreply, assign(socket, session_id: session_id, link: path, full_url: full_url)}
    else
      error_msg = cond do
        draft_title == "" -> "Please enter a draft title"
        length(members) < total_min_members -> "Please enter at least #{total_min_members} members (minimum of #{min_members_per_league} per league)"
        true -> "Please enter a draft title and enough members"
      end

      Logger.warning("Invalid draft setup: draft_title=#{draft_title}, members_count=#{length(members)}, num_leagues=#{num_leagues}")
      {:noreply, put_flash(socket, :error, error_msg)}
    end
  end

  @impl true
  def handle_info({:remove_member, index}, socket) do
    updated_members = List.delete_at(socket.assigns.members, index)
    # Ensure we always have at least one input field
    updated_members = if updated_members == [], do: [""], else: updated_members
    {:noreply, assign(socket, members: updated_members)}
  end

  @impl true
  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket, :info)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full max-w-xl mx-auto mt-4 sm:mt-10 p-4 sm:p-6 rounded shadow bg-base-200 text-base-content">
      <h1 class="text-2xl sm:text-3xl font-bold mb-4 text-primary">Create a New Draft</h1>
      <form phx-submit="start_draft" phx-change="form_change">
        <div class="mb-4">
          <label class="block mb-1 font-semibold" for="draft_title">Draft Title</label>
          <input id="draft_title" name="draft_title" type="text" value={@draft_title} placeholder="Enter draft title" class="w-full px-2 py-2 border border-base-300 rounded bg-base-100 text-base-content" />
        </div>
        <div class="mb-4">
          <label class="block mb-1 font-semibold" for="num_leagues">Number of Leagues</label>
          <input
            id="num_leagues"
            name="num_leagues"
            type="number"
            min="1"
            value={@num_leagues}
            placeholder="Number of leagues"
            class="w-full px-2 py-2 border border-base-300 rounded bg-base-100 text-base-content"
          />
          <p class="text-sm text-base-content/70 mt-1">Minimum of 2 members per league required</p>
        </div>
        <div class="mb-4">
          <label class="block mb-1 font-semibold">League Names</label>
          <%= for league_idx <- 1..@num_leagues do %>
            <div class="mb-2 flex items-center">
              <span class="mr-2 font-semibold w-6 text-right"><%= league_idx %>.</span>
              <input 
                type="text" 
                name={"league_name_#{league_idx}"} 
                value={Map.get(@league_names, league_idx, "League #{league_idx}")} 
                placeholder={"League #{league_idx} name"} 
                class="flex-1 px-2 py-2 border border-base-300 rounded bg-base-100 text-base-content" 
              />
            </div>
          <% end %>
        </div>
        <label class="block mb-1 font-semibold">Members</label>
        <div id="members-list" phx-hook="AnimatedList" class="members-list">
          <%= for {member, idx} <- Enum.with_index(@members) do %>
            <div data-member-item class="mb-2 flex items-center transition-height">
              <input type="text" name={"member_#{idx}"} value={member} placeholder="Member name" class="flex-1 px-2 py-2 border border-base-300 rounded bg-base-100 text-base-content" />
              <button type="button" phx-click="remove_member" phx-value-index={idx} class="ml-2 p-1 rounded hover:bg-base-300 transition-colors" aria-label="Remove member">
                <.icon name="hero-x-mark" class="size-5 text-error" />
              </button>
            </div>
          <% end %>
        </div>
        <div class="mt-2 flex flex-wrap gap-2">
          <button type="button" phx-click="add_member" class="px-4 py-2 bg-secondary text-secondary-content rounded whitespace-nowrap">Add Member</button>
          <button type="submit" class="px-4 py-2 bg-primary text-primary-content rounded whitespace-nowrap">Generate Draft</button>
        </div>
        <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
          <div class="mt-4 p-2 bg-info text-info-content rounded animate-fade-in">
            <%= flash %>
          </div>
        <% end %>
        <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
          <div class="mt-4 p-2 bg-error text-error-content rounded">
            <%= flash %>
          </div>
        <% end %>
      </form>
      <%= if @link do %>
        <div class="mt-6 p-4 bg-success text-success-content rounded">
          <p class="mb-2 font-semibold">Share this link with your league members:</p>
          <div class="flex flex-col sm:flex-row mb-2">
            <p id="draft-link" class="bg-base-100 p-2 rounded-t sm:rounded-t-none sm:rounded-l border border-base-300 text-base-content font-mono text-sm break-all flex-1"><%= @full_url %></p>
            <button
              id="copy-button"
              phx-hook="CopyToClipboard"
              data-copy-target="draft-link"
              class="p-2 bg-base-100 rounded-b sm:rounded-b-none sm:rounded-r border border-t-0 sm:border-t sm:border-l-0 border-base-300 text-base-content hover:bg-base-200 transition-colors duration-200"
              aria-label="Copy link"
            >
              <span class="flex items-center justify-center">
                <.icon name="hero-document-duplicate" class="size-5 text-primary" />
                <span data-feedback class="ml-1 text-xs">Copy</span>
              </span>
            </button>
          </div>
          <div class="mt-3">
            <a href={@link} class="px-4 py-2 bg-info text-info-content rounded inline-block">Go to Draft</a>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
