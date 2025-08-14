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
  Creates a new draft session with a unique ID, league name, and member list.
  Returns the session ID.
  """
  def create_session(league_name, members) when is_binary(league_name) and is_list(members) do
    session_id = Ecto.UUID.generate()
    GenServer.call(__MODULE__, {:create_session, session_id, league_name, members})
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

  # GenServer Callbacks

  def init(state) do
    {:ok, state}
  end


  def handle_call({:create_session, session_id, league_name, members}, _from, state) do
    new_state = Map.put(state, session_id, %{
      league_name: league_name,
      members: members,
      remaining: members,
      revealed: []
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
      %{remaining: remaining, revealed: revealed} = session ->
        [next | _rest] = Enum.shuffle(remaining)
        new_revealed = revealed ++ [next]
        new_session = %{session | remaining: List.delete(remaining, next), revealed: new_revealed}
        new_state = Map.put(state, session_id, new_session)
        {:reply, new_revealed, new_state}
    end
  end

  def handle_cast({:delete_session, session_id}, state) do
    {:noreply, Map.delete(state, session_id)}
  end
end
