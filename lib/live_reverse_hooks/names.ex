defmodule LiveReverseHooks.Names do
  @moduledoc false
  # The names two hooks of a LiveView can't share, e.g. `{:assign, key}`,
  # `{:param, name}` (they share the URL query) or `{:event, name}`.

  import Phoenix.LiveView, only: [put_private: 3]

  @doc """
  Raises on `opts` keys missing from `defaults`.
  """
  def validate_opts!(opts, defaults, hook) do
    case Keyword.keys(opts) -- Keyword.keys(defaults) do
      [] -> :ok
      unknown -> raise ArgumentError, "unknown #{hook} options #{inspect(unknown)}"
    end
  end

  @doc """
  Marks `names` as used, raising if one already is. `nil` names are
  skipped.
  """
  def claim!(socket, names) do
    names = reject_nil(names)
    used = used(socket)

    case Enum.find(names, &(&1 in used or &1 in (names -- [&1]))) do
      nil -> put_private(socket, __MODULE__, names ++ used)
      {kind, name} -> raise ArgumentError, "#{kind} #{inspect(name)} is already used"
    end
  end

  @doc """
  Frees `names` claimed by `claim!/2`.
  """
  def release(socket, names),
    do: put_private(socket, __MODULE__, used(socket) -- reject_nil(names))

  @doc """
  Returns the used names of `kind`.
  """
  def used(socket, kind), do: for({^kind, name} <- used(socket), do: name)

  defp used(socket), do: socket.private[__MODULE__] || []

  defp reject_nil(names), do: Enum.reject(names, fn {_kind, name} -> is_nil(name) end)
end
