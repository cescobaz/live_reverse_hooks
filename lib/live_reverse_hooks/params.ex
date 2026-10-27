defmodule LiveReverseHooks.Params do
  @moduledoc ~S"""
  Assigns URL params to the socket on every `handle_params`.

  Each binding maps an assign key to a param name, or to `:uri` for the
  full URI. Empty strings are assigned as `nil`.

      on_mount {LiveReverseHooks.Params, uri: :uri, project_id: "project_id"}

  It can be listed more than once: every entry's bindings are applied by
  one hook, and binding the same assign key twice raises.
  `LiveReverse.detach/3` with an entry's bindings unbinds them; the hook
  goes with the last ones.

  `build/2` turns the bound assigns back into URL params, e.g. to patch:

      push_patch(socket, to: ~p"/projects/#{id}?#{Params.build(socket, search: "x")}")
  """
  use LiveReverse, attach: :once
  import Phoenix.LiveView, only: [put_private: 3]
  alias Phoenix.LiveView.Socket

  @uri_key {__MODULE__, :uri}

  @doc """
  Returns the bound params, read from the assigns and keyed by param name.

  `overrides` (map or keyword) is keyed by assign key and wins over the
  assigns; keys that are not bound are ignored. `:uri` bindings are skipped
  and `nil` values are dropped, so `key: nil` removes a param.
  """
  def build(socket, overrides \\ %{}) do
    overrides = Map.new(overrides)

    for {key, param} <- Enum.concat(LiveReverse.args(socket, __MODULE__)), param != :uri do
      {param, Map.get(overrides, key, socket.assigns[key])}
    end
    |> Enum.reject(fn {_param, value} -> is_nil(value) end)
    |> Map.new()
  end

  @doc """
  Returns the path of `uri` with `query` merged into its query string.

  With a socket, `uri` is the one stored by the last `handle_params` (see
  `put_uri/2`):

      push_patch(socket, to: Params.build_to(%{"search" => "x"}, socket))
  """
  def build_to(query, %Socket{} = socket) do
    case socket.private[@uri_key] do
      nil -> raise ArgumentError, "no URI stored in the socket, see put_uri/2"
      uri -> build_to(query, uri)
    end
  end

  def build_to(%{} = query, uri) when is_binary(uri) do
    uri = URI.parse(uri)

    query =
      case uri.query do
        nil -> query
        current -> URI.decode_query(current) |> Map.merge(query)
      end
      |> URI.encode_query()

    uri.path <> "?" <> query
  end

  @doc """
  Stores `uri` in the socket for `build_to/2`. The hook calls it on every
  `handle_params`; other hooks can too.
  """
  def put_uri(socket, uri), do: put_private(socket, @uri_key, uri)

  @impl true
  def mount(bindings, _params, _session, socket) do
    validate!(bindings)
    check_unbound!(Enum.concat(LiveReverse.args(socket, __MODULE__)), bindings)

    {:cont, assign_defaults(socket, bindings)}
  end

  @impl true
  def handle_params(groups, params, uri, socket) do
    socket =
      for bindings <- groups, binding <- bindings, reduce: put_uri(socket, uri) do
        socket ->
          case binding do
            {key, :uri} -> assign(socket, key, uri)
            {key, param} -> assign(socket, key, blank_to_nil(Map.get(params, param)))
          end
      end

    {:cont, socket}
  end

  defp check_unbound!(current, bindings) do
    case Keyword.keys(current) -- (Keyword.keys(current) -- Keyword.keys(bindings)) do
      [] -> :ok
      dups -> raise ArgumentError, "params #{inspect(dups)} are already bound"
    end
  end

  defp assign_defaults(socket, bindings) do
    Enum.reduce(bindings, socket, fn {key, _}, socket ->
      assign_new(socket, key, fn -> nil end)
    end)
  end

  defp validate!(bindings) do
    unless Keyword.keyword?(bindings) and bindings != [] do
      raise ArgumentError,
            "expected a non-empty keyword list of param bindings, got: #{inspect(bindings)}"
    end

    for {key, param} <- bindings, param != :uri and not is_binary(param) do
      raise ArgumentError,
            "bad param binding #{inspect({key, param})}, expected a param name or :uri"
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
