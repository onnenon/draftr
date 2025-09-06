defmodule DraftrWeb.DraftSetupLive do
  use DraftrWeb, :live_view

  alias Draftr.DraftSession

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
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
      socket =
        put_flash(socket, :info, "Please use the existing empty field before adding a new one")

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

  @impl true
  def handle_event("add_league", _params, socket) do
    # Increment the number of leagues
    num_leagues = socket.assigns.num_leagues + 1

    # Add the new league with default name
    league_names = Map.put(socket.assigns.league_names, num_leagues, "League #{num_leagues}")

    # First update the state
    socket = assign(socket, num_leagues: num_leagues, league_names: league_names)

    # Send event to trigger animation
    socket = push_event(socket, "item_added", %{target: "leagues-list", index: num_leagues - 1})

    {:noreply, socket}
  end

  def handle_event("remove_member", %{"index" => index}, socket) do
    index = String.to_integer(index)
    # First send animation event before removing the item
    socket = push_event(socket, "item_removed", %{index: index})

    # Then remove the item after a delay to allow animation to play
    Process.send_after(self(), {:remove_member, index}, 300)
    {:noreply, socket}
  end

  def handle_event("remove_league", %{"index" => index}, socket) do
    index = String.to_integer(index)

    # Don't allow removing the last league
    if socket.assigns.num_leagues <= 1 do
      socket = put_flash(socket, :info, "At least one league is required")
      Process.send_after(self(), :clear_flash, 3000)
      {:noreply, socket}
    else
      # Send animation event before removing the item
      socket = push_event(socket, "item_removed", %{target: "leagues-list", index: index - 1})

      # Then remove the league after a delay to allow animation to play
      Process.send_after(self(), {:remove_league, index}, 300)
      {:noreply, socket}
    end
  end

  def handle_event("form_change", params, socket) do
    draft_title = params["draft_title"] || ""

    # Get the current number of leagues
    num_leagues = socket.assigns.num_leagues

    # Get all league names
    league_names =
      Enum.reduce(1..num_leagues, %{}, fn idx, acc ->
        name = params["league_name_#{idx}"] || "League #{idx}"
        Map.put(acc, idx, name)
      end)

    # Get all member inputs
    members =
      socket.assigns.members
      |> Enum.with_index()
      |> Enum.map(fn {_member, idx} ->
        params["member_#{idx}"] || ""
      end)

    {:noreply,
     assign(socket, draft_title: draft_title, members: members, league_names: league_names)}
  end

  def handle_event("start_draft", params, socket) do
    require Logger
    Logger.info("Start draft event triggered with params: #{inspect(params)}")

    members = Enum.filter(socket.assigns.members, &(&1 != ""))
    draft_title = String.trim(socket.assigns.draft_title)
    num_leagues = socket.assigns.num_leagues
    league_names = Map.values(socket.assigns.league_names)

    Logger.info(
      "Draft title: #{inspect(draft_title)}, Members: #{inspect(members)}, Num leagues: #{num_leagues}, League names: #{inspect(league_names)}"
    )

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

      # Store in local storage that this user is the creator
      socket = push_event(socket, "store-draft-creator", %{session_id: session_id})

      {:noreply, assign(socket, session_id: session_id, link: path, full_url: full_url)}
    else
      error_msg =
        cond do
          draft_title == "" ->
            "Please enter a draft title"

          length(members) < total_min_members ->
            "Please enter at least #{total_min_members} members (minimum of #{min_members_per_league} per league)"

          true ->
            "Please enter a draft title and enough members"
        end

      Logger.warning(
        "Invalid draft setup: draft_title=#{draft_title}, members_count=#{length(members)}, num_leagues=#{num_leagues}"
      )

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
  def handle_info({:remove_league, index}, socket) do
    # Decrease the number of leagues
    num_leagues = socket.assigns.num_leagues - 1

    # Remove the league from league_names and renumber remaining leagues
    league_names =
      socket.assigns.league_names
      |> Map.delete(index)
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        cond do
          k < index -> Map.put(acc, k, v)
          k > index -> Map.put(acc, k - 1, v)
          true -> acc
        end
      end)

    {:noreply, assign(socket, num_leagues: num_leagues, league_names: league_names)}
  end

  @impl true
  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket, :info)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="draft-creator-container" phx-hook="DraftCreator" class="container mx-auto max-w-2xl">
      <div class="card-body bg-base-300/50">
        <h1 class="text-3xl sm:text-3xl font-bold text-accent">Create a New Draft</h1>
        <form phx-submit="start_draft" phx-change="form_change">
          <div class="pt-12">
            <label class="block mb-2 text-xl font-semibold" for="draft_title">Draft Title</label>
            <input
              id="draft_title"
              name="draft_title"
              type="text"
              value={@draft_title}
              placeholder="Enter draft title"
              class="input"
            />
          </div>
          <h2 class="font-semibold text-xl pt-12">Leagues</h2>
          <div id="leagues-list" phx-hook="AnimatedList" class="leagues-list">
            <%= for league_idx <- 1..@num_leagues do %>
              <div data-league-item class="join mb-2 flex items-center transition-height">
                <input
                  type="text"
                  name={"league_name_#{league_idx}"}
                  value={Map.get(@league_names, league_idx, "")}
                  placeholder="League name"
                  class="input"
                />
                <button
                  type="button"
                  phx-click="remove_league"
                  phx-value-index={league_idx}
                  class="btn btn-outline btn-square btn-error"
                  aria-label="Remove league"
                >
                  <.icon name="hero-x-mark" class="size-5 text-error" />
                </button>
              </div>
            <% end %>
          </div>
          <div class="mt-4">
            <button type="button" phx-click="add_league" class="btn btn-primary">
              <.icon name="hero-plus" class="size-4 mr-1" /> Add League
            </button>
          </div>
          <p class="text-sm text-base-content/70 pt-2">Minimum of 2 members per league required</p>

          <h2 class="font-semibold text-lg pt-12">Members</h2>
          <div id="members-list" phx-hook="AnimatedList" class="members-list">
            <%= for {member, idx} <- Enum.with_index(@members) do %>
              <div data-member-item class="join mb-2 flex items-center transition-height">
                <input
                  type="text"
                  name={"member_#{idx}"}
                  value={member}
                  placeholder="Member name"
                  class="input"
                />
                <button
                  type="button"
                  phx-click="remove_member"
                  phx-value-index={idx}
                  class="btn btn-outline btn-square btn-error"
                  aria-label="Remove member"
                >
                  <.icon name="hero-x-mark" class="size-5 text-error" />
                </button>
              </div>
            <% end %>
          </div>
          <div class="mt-4">
            <button type="button" phx-click="add_member" class="btn btn-primary">
              <.icon name="hero-plus" class="size-4 mr-1" /> Add Member
            </button>
          </div>

          <div class="mt-6 flex justify-center">
            <button type="submit" class="btn btn-secondary">Generate Draft</button>
          </div>
          <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
            <div class="mt-4 p-3 alert alert-info alert-soft animate-fade-in">
              {flash}
            </div>
          <% end %>
          <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
            <div class="mt-4 p-3 alert alert-error alert-soft animate-fade-in">
              {flash}
            </div>
          <% end %>
        </form>
        <%= if @link do %>
          <div class="card mt-20 shadow bg-base-300">
            <div class="card-body">
              <p class="card-title">Share this link with your league members:</p>
              <div class="card bg-base-100 flex-row">
                <p
                  id="draft-link"
                  class="h-24 font-mono text-md text-accent p-4 place-content-center"
                >
                  {@full_url}
                </p>
                <button
                  id="copy-button"
                  phx-hook="CopyToClipboard"
                  data-copy-target="draft-link"
                  class="btn btn-lg btn-primary h-24"
                  aria-label="Copy link"
                >
                  <span class="flex items-center justify-center">
                    <.icon name="hero-document-duplicate" class="size-5" />
                    <span data-feedback class="ml-1 text-xs">Copy</span>
                  </span>
                </button>
              </div>
              <div class="mt-4">
                <a
                  href={@link}
                  class="px-5 py-2.5 btn btn-primary"
                >
                  Go to Draft
                </a>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
