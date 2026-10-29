defmodule LiveReverseHooks.SearchTest do
  use ExUnit.Case, async: true

  alias LiveReverseHooks.Search
  alias Phoenix.LiveView.{Lifecycle, Socket}

  defmodule CustomSearch do
    use LiveReverseHooks.Search

    @impl LiveReverseHooks.Search
    def handle_search_change(arg, search, socket),
      do: super(arg, search, assign(socket, :changed_to, search))
  end

  # handle_params hooks need a socket mounted at a router, any module will do
  defp socket do
    %Socket{router: __MODULE__, private: %{lifecycle: %Lifecycle{}, live_temp: %{}}}
  end

  defp mount(socket, arg, module \\ Search) do
    {:cont, socket} = module.on_mount(arg, %{}, %{}, socket)
    socket
  end

  defp run_handle_params(socket, params, uri) do
    Enum.reduce(socket.private.lifecycle.handle_params, socket, fn hook, socket ->
      {:cont, socket} = hook.function.(params, uri, socket)
      socket
    end)
  end

  defp run_handle_event(socket, event, payload) do
    Enum.reduce_while(socket.private.lifecycle.handle_event, {:cont, socket}, fn hook,
                                                                                 {_, socket} ->
      case hook.function.(event, payload, socket) do
        {:cont, socket} -> {:cont, {:cont, socket}}
        {:halt, socket} -> {:halt, {:halt, socket}}
      end
    end)
  end

  test "assigns the param, with empty as nil" do
    socket = mount(socket(), :default)
    assert socket.assigns.search == nil

    socket = run_handle_params(socket, %{"search" => "x"}, "http://h/a?b=1")
    assert socket.assigns.search == "x"

    socket = run_handle_params(socket, %{"search" => ""}, "http://h/a")
    assert socket.assigns.search == nil
  end

  test "search event patches and halts, the patch assigns" do
    socket =
      socket()
      |> mount(:default)
      |> run_handle_params(%{}, "http://h/a?b=1")

    assert {:halt, socket} = run_handle_event(socket, "search", %{"search" => "y"})
    assert socket.assigns.search == nil
    assert {:live, :patch, %{to: to}} = socket.redirected
    assert URI.decode_query(URI.parse(to).query) == %{"b" => "1", "search" => "y"}

    socket = run_handle_params(socket, URI.decode_query(URI.parse(to).query), "http://h" <> to)
    assert socket.assigns.search == "y"

    assert {:cont, _} = run_handle_event(socket, "other", %{})
  end

  test "search event drops params, and skips an unchanged search" do
    socket =
      socket()
      |> mount(drop_params_on_change: ["page", "size"])
      |> run_handle_params(%{"search" => "x"}, "http://h/a?b=1&page=3&size=5&search=x")

    assert {:halt, socket} = run_handle_event(socket, "search", %{"search" => "y"})
    assert {:live, :patch, %{to: to}} = socket.redirected
    assert URI.decode_query(URI.parse(to).query) == %{"b" => "1", "search" => "y"}

    socket =
      run_handle_params(
        %{socket | redirected: nil},
        %{"search" => "y"},
        "http://h/a?search=y&page=2"
      )

    assert {:halt, socket} = run_handle_event(socket, "search", %{"search" => "y"})
    assert socket.redirected == nil

    assert {:halt, socket} = run_handle_event(socket, "search", %{"search" => ""})
    assert {:live, :patch, %{to: "/a"}} = socket.redirected
  end

  test "a module using Search overrides handle_search_change" do
    socket =
      socket()
      |> mount([drop_params_on_change: ["page"]], CustomSearch)
      |> run_handle_params(%{}, "http://h/a?page=2")

    assert {:halt, socket} = run_handle_event(socket, "search", %{"search" => "y"})
    assert %{search: nil, changed_to: "y"} = socket.assigns
    assert {:live, :patch, %{to: "/a?search=y"}} = socket.redirected

    assert_raise ArgumentError, ~r/assign :search is already used/, fn ->
      mount(socket, :default)
    end
  end

  test "custom options and several entries" do
    socket =
      socket()
      |> mount(:default)
      |> mount(
        key: :tag_search,
        search_param: "q",
        event: "tag_search",
        event_search_path: "value"
      )
      |> run_handle_params(%{"search" => "a", "q" => "b"}, "http://h/a")

    assert %{search: "a", tag_search: "b"} = socket.assigns

    {:halt, socket} = run_handle_event(socket, "tag_search", %{"value" => "c"})
    assert {:live, :patch, %{to: "/a?q=c"}} = socket.redirected
  end

  test "nested event path, no event and unknown options" do
    socket =
      socket()
      |> mount(event_search_path: ["form", "q"])
      |> mount(key: :other, search_param: "other", event: nil)
      |> run_handle_params(%{}, "http://h/a")

    assert {:halt, socket} = run_handle_event(socket, "search", %{"form" => %{"q" => "z"}})
    assert {:live, :patch, %{to: "/a?search=z"}} = socket.redirected

    assert_raise ArgumentError, ~r/unknown search options \[:param\]/, fn ->
      mount(socket(), param: "q")
    end
  end

  test "raises on a used assign, param or event, also of another hook" do
    socket = mount(socket(), :default)

    assert_raise ArgumentError, ~r/assign :search is already used/, fn ->
      mount(socket, search_param: "q", event: "q")
    end

    assert_raise ArgumentError, ~r/param "search" is already used/, fn ->
      mount(socket, key: :q, event: "q")
    end

    assert_raise ArgumentError, ~r/event "search" is already used/, fn ->
      mount(socket, key: :q, search_param: "q")
    end

    assert_raise ArgumentError, ~r/param "search" is already used/, fn ->
      LiveReverseHooks.Pagination.on_mount([page_param: "search"], %{}, %{}, socket)
    end

    socket = LiveReverse.detach(socket, Search)
    assert mount(socket, :default)
  end

  test "build_params" do
    assert Search.build_params(:default, "x") == %{"search" => "x"}

    assert Search.build_params([search_param: "q", drop_params_on_change: ["page"]], nil) ==
             %{"q" => nil, "page" => nil}
  end

  test "search?" do
    assert Search.search?("x")
    refute Search.search?("")
    refute Search.search?(nil)
    assert Search.search?(%{search: "x"})
    assert Search.search?(%{q: "x"}, :q)
  end

  test "get_search" do
    assert Search.get_search(%{search: "x"}) == "x"
    assert Search.get_search(%{search: nil}) == nil
    assert Search.get_search(%{q: "x"}, :q) == "x"
    assert Search.get_search(%Phoenix.LiveView.Socket{assigns: %{search: "x"}}) == "x"
  end
end
