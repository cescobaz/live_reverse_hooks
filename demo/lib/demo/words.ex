defmodule Demo.Words do
  @moduledoc """
  An in-memory data source of words, one namespace per user.

  A GenServer holds the state, so it is lost on restart. Every function
  is scoped to a user: a user never reads or changes the words of
  another one.

  The CRUD functions return `{:ok, result}` or `{:error, reason}`, never
  `nil`: `:not_found` for a missing user or word, `:unprocessable_entity`
  for invalid params.

  ## Events

  A change is broadcast to the subscribers of the user (see
  `subscribe/1`), only theirs:

    * `{Demo.Words, :created, %Word{}}`
    * `{Demo.Words, :updated, %Word{}}`
    * `{Demo.Words, :deleted, %Word{}}`
    * `{Demo.Words, :reset, user_id}` - see `reset_user/1`
  """
  use GenServer
  alias Demo.Words.{Query, Word}

  @presets ~w(
    apple banana cherry date elderberry fig grape honeydew kiwi lemon
    mango nectarine orange papaya quince raspberry strawberry tangerine
    ugli vanilla watermelon yam zucchini apricot blueberry coconut
    durian guava lime lychee melon olive peach pear plum pomegranate
  )

  def start_link(opts \\ []),
    do: GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, __MODULE__))

  ## Events

  @doc "Subscribes the caller to the events of the words of `user_id`."
  def subscribe(user_id) when is_binary(user_id),
    do: Phoenix.PubSub.subscribe(Demo.PubSub, topic(user_id))

  @doc "Undoes `subscribe/1`."
  def unsubscribe(user_id) when is_binary(user_id),
    do: Phoenix.PubSub.unsubscribe(Demo.PubSub, topic(user_id))

  defp topic(user_id), do: "words:" <> user_id

  defp broadcast(user_id, event, payload),
    do: Phoenix.PubSub.broadcast(Demo.PubSub, topic(user_id), {__MODULE__, event, payload})

  # Broadcasts `event` for the word of a successful `result`, and returns it.
  defp broadcast_word({:ok, %Word{} = word} = result, event) do
    broadcast(word.user_id, event, word)
    result
  end

  defp broadcast_word(result, _event), do: result

  ## Users

  @doc "Returns the words a new user starts with."
  def presets, do: @presets

  @doc "Returns whether `user_id` has a set of words."
  def user?(user_id) when is_binary(user_id), do: GenServer.call(__MODULE__, {:user?, user_id})

  @doc """
  Gives `user_id` the preset words, if it has no set yet. Returns
  `{:ok, :created}` or `{:ok, :exists}`.
  """
  def init_user(user_id) when is_binary(user_id),
    do: GenServer.call(__MODULE__, {:init_user, user_id})

  @doc "Replaces the words of `user_id` with the preset ones."
  def reset_user(user_id) when is_binary(user_id) do
    :ok = GenServer.call(__MODULE__, {:reset_user, user_id})
    broadcast(user_id, :reset, user_id)
  end

  @doc "Removes `user_id` and its words, with no event."
  def delete_user(user_id) when is_binary(user_id),
    do: GenServer.call(__MODULE__, {:delete_user, user_id})

  ## CRUD

  @doc "Returns the word `id` of `user_id`."
  def get(%{user_id: user_id, id: id}) when is_binary(user_id) and is_integer(id),
    do: GenServer.call(__MODULE__, {:get, user_id, id})

  def get(%{}), do: {:error, :unprocessable_entity}

  @doc """
  Returns the words of a `Demo.Words.Query`, ordered by text. `:search`
  keeps the words that contain it, ignoring case.
  """
  def list(params) do
    with {:ok, query} <- Query.validate(params),
         do: GenServer.call(__MODULE__, {:list, query})
  end

  @doc "Returns the number of words of a `Demo.Words.Query`, ignoring `:offset` and `:limit`."
  def count(params) do
    with {:ok, query} <- Query.validate(params),
         do: GenServer.call(__MODULE__, {:count, query})
  end

  @doc """
  Adds a word to `user_id`. The text is trimmed, and it must not be empty
  or already there.
  """
  def create(%{user_id: user_id, text: text}) when is_binary(user_id) and is_binary(text),
    do:
      GenServer.call(__MODULE__, {:create, user_id, String.trim(text)})
      |> broadcast_word(:created)

  def create(%{}), do: {:error, :unprocessable_entity}

  @doc "Changes the text of `word`, with the rules of `create/1`."
  def update(%Word{} = word, %{text: text}) when is_binary(text),
    do:
      GenServer.call(__MODULE__, {:update, word.user_id, word.id, String.trim(text)})
      |> broadcast_word(:updated)

  def update(%Word{}, %{}), do: {:error, :unprocessable_entity}

  @doc "Removes a word, given as a `Word` or as `%{user_id: user_id, id: id}`."
  def delete(%{user_id: user_id, id: id}) when is_binary(user_id) and is_integer(id),
    do: GenServer.call(__MODULE__, {:delete, user_id, id}) |> broadcast_word(:deleted)

  def delete(%{}), do: {:error, :unprocessable_entity}

  ## Server

  @impl true
  def init(users), do: {:ok, users}

  @impl true
  def handle_call({:user?, user_id}, _from, users),
    do: {:reply, Map.has_key?(users, user_id), users}

  def handle_call({:init_user, user_id}, _from, users) do
    if Map.has_key?(users, user_id),
      do: {:reply, {:ok, :exists}, users},
      else: {:reply, {:ok, :created}, Map.put(users, user_id, preset(user_id))}
  end

  def handle_call({:reset_user, user_id}, _from, users),
    do: {:reply, :ok, Map.put(users, user_id, preset(user_id))}

  def handle_call({:delete_user, user_id}, _from, users),
    do: {:reply, :ok, Map.delete(users, user_id)}

  def handle_call({:get, user_id, id}, _from, users) do
    with {:ok, user} <- fetch_user(users, user_id),
         {:ok, word} <- fetch_word(user, id) do
      {:reply, {:ok, word}, users}
    else
      error -> {:reply, error, users}
    end
  end

  def handle_call({:list, query}, _from, users) do
    reply =
      with {:ok, words} <- filter(users, query) do
        words = Enum.drop(words, query.offset)
        {:ok, if(query.limit, do: Enum.take(words, query.limit), else: words)}
      end

    {:reply, reply, users}
  end

  def handle_call({:count, query}, _from, users) do
    reply = with {:ok, words} <- filter(users, query), do: {:ok, length(words)}
    {:reply, reply, users}
  end

  def handle_call({:create, user_id, text}, _from, users) do
    with {:ok, user} <- fetch_user(users, user_id),
         :ok <- validate_text(user, text, nil) do
      word = %Word{id: user.next_id, user_id: user_id, text: text}
      user = %{user | next_id: user.next_id + 1, words: Map.put(user.words, word.id, word)}
      {:reply, {:ok, word}, Map.put(users, user_id, user)}
    else
      error -> {:reply, error, users}
    end
  end

  def handle_call({:update, user_id, id, text}, _from, users) do
    with {:ok, user} <- fetch_user(users, user_id),
         {:ok, word} <- fetch_word(user, id),
         :ok <- validate_text(user, text, id) do
      word = %{word | text: text}
      user = %{user | words: Map.put(user.words, id, word)}
      {:reply, {:ok, word}, Map.put(users, user_id, user)}
    else
      error -> {:reply, error, users}
    end
  end

  def handle_call({:delete, user_id, id}, _from, users) do
    with {:ok, user} <- fetch_user(users, user_id),
         {:ok, word} <- fetch_word(user, id) do
      user = %{user | words: Map.delete(user.words, id)}
      {:reply, {:ok, word}, Map.put(users, user_id, user)}
    else
      error -> {:reply, error, users}
    end
  end

  defp preset(user_id) do
    words =
      @presets
      |> Enum.with_index(1)
      |> Map.new(fn {text, id} -> {id, %Word{id: id, user_id: user_id, text: text}} end)

    %{next_id: length(@presets) + 1, words: words}
  end

  defp fetch_user(users, user_id) do
    case Map.fetch(users, user_id) do
      {:ok, user} -> {:ok, user}
      :error -> {:error, :not_found}
    end
  end

  defp fetch_word(user, id) do
    case Map.fetch(user.words, id) do
      {:ok, word} -> {:ok, word}
      :error -> {:error, :not_found}
    end
  end

  defp filter(users, %Query{} = query) do
    with {:ok, user} <- fetch_user(users, query.user_id) do
      search = query.search && String.downcase(query.search)

      user.words
      |> Map.values()
      |> Enum.filter(&(search in [nil, ""] or String.contains?(String.downcase(&1.text), search)))
      |> Enum.sort_by(& &1.text)
      |> then(&{:ok, &1})
    end
  end

  # A text is valid if not empty and not the text of another word.
  defp validate_text(_user, "", _id), do: {:error, :unprocessable_entity}

  defp validate_text(user, text, id) do
    if Enum.any?(Map.values(user.words), &(&1.text == text and &1.id != id)),
      do: {:error, :unprocessable_entity},
      else: :ok
  end
end
