defmodule DraftrWeb.DraftSetupLive do
  use DraftrWeb, :live_view

  alias Draftr.DraftSession

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, league_name: "", members: [""], session_id: nil, link: nil, full_url: nil)}
  end

  @impl true
  def handle_event("add_member", _params, socket) do
    {:noreply, update(socket, :members, fn members -> members ++ [""] end)}
  end

  def handle_event("form_change", params, socket) do
    league_name = params["league_name"] || ""

    # Get all member inputs
    members = socket.assigns.members
    |> Enum.with_index()
    |> Enum.map(fn {_member, idx} ->
      params["member_#{idx}"] || ""
    end)

    {:noreply, assign(socket, league_name: league_name, members: members)}
  end

  def handle_event("start_draft", params, socket) do
    require Logger
    Logger.info("Start draft event triggered with params: #{inspect(params)}")

    members = Enum.filter(socket.assigns.members, &(&1 != ""))
    league_name = String.trim(socket.assigns.league_name)

    Logger.info("League name: #{inspect(league_name)}, Members: #{inspect(members)}")

    if league_name != "" and length(members) > 1 do
      session_id = DraftSession.create_session(league_name, members)
      Logger.info("Session created with ID: #{inspect(session_id)}")

      # Generate the path
      path = ~p"/draft/#{session_id}"

      # Generate the full URL based on the endpoint configuration
      url = DraftrWeb.Endpoint.url()
      full_url = "#{url}#{path}"

      {:noreply, assign(socket, session_id: session_id, link: path, full_url: full_url)}
    else
      Logger.warning("Invalid draft setup: league_name=#{league_name}, members_count=#{length(members)}")
      {:noreply, put_flash(socket, :error, "Please enter a league name and at least 2 members")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-xl mx-auto mt-10 p-6 rounded shadow bg-base-200 text-base-content">
      <h1 class="text-3xl font-bold mb-4 text-primary">Create a New Draft</h1>
      <form phx-submit="start_draft" phx-change="form_change">
        <div class="mb-4">
          <label class="block mb-1 font-semibold" for="league_name">League Name</label>
          <input id="league_name" name="league_name" type="text" value={@league_name} placeholder="Enter league name" class="w-full px-2 py-2 border border-base-300 rounded bg-base-100 text-base-content focus:outline-primary" />
        </div>
        <label class="block mb-1 font-semibold">Members</label>
        <%= for {member, idx} <- Enum.with_index(@members) do %>
          <div class="mb-2 flex">
            <input type="text" name={"member_#{idx}"} value={member} placeholder="Member name" class="flex-1 px-2 py-2 border border-base-300 rounded bg-base-100 text-base-content focus:outline-primary" />
          </div>
        <% end %>
        <div class="mt-2 flex items-center">
          <button type="button" phx-click="add_member" class="px-3 py-1 bg-secondary text-secondary-content rounded">Add Member</button>
          <button type="submit" class="ml-2 px-4 py-2 bg-primary text-primary-content rounded">Generate Draft</button>
        </div>
        <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
          <div class="mt-4 p-2 bg-error text-error-content rounded">
            <%= flash %>
          </div>
        <% end %>
      </form>
      <%= if @link do %>
        <div class="mt-6 p-4 bg-success text-success-content rounded">
          <p class="mb-2 font-semibold">Share this link with your league members:</p>
          <div class="flex items-center mb-2">
            <p id="draft-link" class="bg-base-100 p-2 rounded-l border-l border-t border-b border-base-300 text-base-content font-mono text-sm break-all flex-1"><%= @full_url %></p>
            <button
              id="copy-button"
              phx-hook="CopyToClipboard"
              data-copy-target="draft-link"
              class="p-2 bg-base-100 rounded-r border-t border-r border-b border-base-300 text-base-content hover:bg-base-200 transition-colors duration-200"
              aria-label="Copy link"
            >
              <span class="flex items-center">
                <.icon name="hero-document-duplicate" class="size-5 text-primary" />
                <span data-feedback class="ml-1 text-xs hidden sm:inline">Copy</span>
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
