defmodule Draftr.DraftSession do
  @moduledoc """
  Manages in-memory draft sessions for ephemeral fantasy draft pick orders.
  Each session is identified by a unique ID and stores members and pick order in memory only.
  """

  use GenServer

  # Public API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end


  @doc """
  Creates a new draft session with a unique ID, draft title, member list, and number of leagues.
  Returns the session ID.
  """
  def create_session(draft_title, members, num_leagues \\ 1, league_names \\ nil) when is_binary(draft_title) and is_list(members) and is_integer(num_leagues) do
    session_id = Ecto.UUID.generate()
    # If league_names are not provided, create default names
    league_names = league_names || Enum.map(1..num_leagues, fn i -> "League #{i}" end)
    GenServer.call(__MODULE__, {:create_session, session_id, draft_title, members, num_leagues, league_names})
    session_id
  end

  @doc """
  Gets the draft session data by session ID.
  Returns %{members: [...], pick_order: [...]} or nil if not found.
  """
  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end


  @doc """
  Reveals the next pick for a session, randomly selecting from remaining members.
  Returns the updated revealed pick order.
  """
  def reveal_next_pick(session_id) do
    GenServer.call(__MODULE__, {:reveal_next_pick, session_id})
  end

  @doc """
  Deletes a session (e.g., after draft is done or timeout).
  """
  def delete_session(session_id) do
    GenServer.cast(__MODULE__, {:delete_session, session_id})
  end

  @doc """
  Increments the viewer count for a session.
  Returns the updated viewer count.
  """
  def increment_viewers(session_id) do
    GenServer.call(__MODULE__, {:increment_viewers, session_id})
  end

  @doc """
  Decrements the viewer count for a session.
  Returns the updated viewer count.
  """
  def decrement_viewers(session_id) do
    GenServer.call(__MODULE__, {:decrement_viewers, session_id})
  end

  # GenServer Callbacks

  def init(state) do
    {:ok, state}
  end


  def handle_call({:create_session, session_id, draft_title, members, num_leagues, league_names}, _from, state) do
    new_state = Map.put(state, session_id, %{
      draft_title: draft_title,
      members: members,
      remaining: members,
      revealed: [],
      viewers: 0,
      num_leagues: num_leagues,
      league_names: league_names,
      league_assignments: %{} # Will store member -> league number mappings
    })
    {:reply, :ok, new_state}
  end

  def handle_call({:get_session, session_id}, _from, state) do
    {:reply, Map.get(state, session_id), state}
  end


  def handle_call({:reveal_next_pick, session_id}, _from, state) do
    case Map.get(state, session_id) do
      nil -> {:reply, nil, state}
      %{remaining: [], revealed: revealed} = _session ->
        {:reply, revealed, state}
      %{remaining: remaining, revealed: revealed, num_leagues: num_leagues, league_assignments: league_assignments} = session ->
        [next | _rest] = Enum.shuffle(remaining)
        new_revealed = revealed ++ [next]

        # Determine which league should get the next member in a simple round-robin order
        # Based on the length of current revealed picks
        current_pick_index = length(revealed)
        # Calculate the league number (1-based) using modulo arithmetic
        league_num = rem(current_pick_index, num_leagues) + 1

        # Update league assignments
        new_league_assignments = Map.put(league_assignments, next, league_num)

        new_session = %{
          session |
          remaining: List.delete(remaining, next),
          revealed: new_revealed,
          league_assignments: new_league_assignments
        }

        new_state = Map.put(state, session_id, new_session)

        # Broadcast the updated draft to all subscribers
        Phoenix.PubSub.broadcast(
          Draftr.PubSub,
          "draft:#{session_id}",
          {:draft_updated, new_session}
        )

        {:reply, new_revealed, new_state}
    end
  end

  def handle_call({:increment_viewers, session_id}, _from, state) do
    case Map.get(state, session_id) do
      nil ->
        {:reply, 0, state}
      session ->
        new_count = (session.viewers || 0) + 1
        new_session = Map.put(session, :viewers, new_count)
        new_state = Map.put(state, session_id, new_session)

        # Broadcast the updated viewer count
        Phoenix.PubSub.broadcast(
          Draftr.PubSub,
          "draft:#{session_id}",
          {:viewers_updated, new_count}
        )

        {:reply, new_count, new_state}
    end
  end

  def handle_call({:decrement_viewers, session_id}, _from, state) do
    case Map.get(state, session_id) do
      nil ->
        {:reply, 0, state}
      session ->
        new_count = max(0, (session.viewers || 0) - 1)
        new_session = Map.put(session, :viewers, new_count)
        new_state = Map.put(state, session_id, new_session)

        # Broadcast the updated viewer count
        Phoenix.PubSub.broadcast(
          Draftr.PubSub,
          "draft:#{session_id}",
          {:viewers_updated, new_count}
        )

        {:reply, new_count, new_state}
    end
  end

  def handle_cast({:delete_session, session_id}, state) do
    {:noreply, Map.delete(state, session_id)}
  end
end
