defmodule LiveReverseHooks.PaginationTest do
  use ExUnit.Case, async: true

  alias LiveReverseHooks.Pagination
  alias Phoenix.LiveView.{Lifecycle, Socket}

  # handle_params hooks need a socket mounted at a router, any module will do
  defp socket do
    %Socket{router: __MODULE__, private: %{lifecycle: %Lifecycle{}, live_temp: %{}}}
  end

  defp mount(socket, arg) do
    {:cont, socket} = Pagination.on_mount(arg, %{}, %{}, socket)
    socket
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

  defp patched_to(%Socket{redirected: {:live, :patch, %{to: to}}}), do: to

  defp run_handle_params(socket, params, uri) do
    Enum.reduce(socket.private.lifecycle.handle_params, socket, fn hook, socket ->
      {:cont, socket} = hook.function.(params, uri, socket)
      socket
    end)
  end

  test "assigns the page, defaulting to 1" do
    socket = mount(socket(), :default)
    assert socket.assigns.page == %{page: 1, size: 20}

    socket = run_handle_params(socket, %{"page" => "3"}, "http://h/a?page=3")
    assert socket.assigns.page == %{page: 3, size: 20}
    assert Pagination.get_page(socket) == 3
    assert Pagination.get_page_size(socket) == 20

    for bad <- ["", "x", "0", "-2", "2x"] do
      socket = run_handle_params(socket, %{"page" => bad}, "http://h/a")
      assert socket.assigns.page.page == 1
    end
  end

  test "custom key and param" do
    socket =
      socket()
      |> mount(key: :p, page_param: "p")
      |> run_handle_params(%{"p" => "2"}, "http://h/a")

    assert socket.assigns.p == %{page: 2, size: 20}
    assert Pagination.get_page(socket, :p) == 2
  end

  test "size, offset and limit" do
    socket =
      socket()
      |> mount(page_size: 10)
      |> run_handle_params(%{"page" => "3"}, "http://h/a")

    assert Pagination.get_page_size(socket) == 10
    assert Pagination.get_limit(socket) == 10
    assert Pagination.get_offset(socket) == 20
    assert Pagination.get_limit(socket, 5) == 5
    assert Pagination.get_offset(socket, 5) == 10
  end

  test "get_page_count" do
    socket =
      socket()
      |> mount(page_size: 10)
      |> mount(key: :other, page_param: "other", event: nil, page_size: 3)
      |> run_handle_params(%{}, "http://h/a")

    assert Pagination.get_page_count(socket, 0) == 1
    assert Pagination.get_page_count(socket, 10) == 1
    assert Pagination.get_page_count(socket, 11) == 2
    assert Pagination.get_page_count(socket, :other, 10) == 4

    socket = socket() |> mount(page_size: nil) |> run_handle_params(%{}, "http://h/a")
    assert_raise ArgumentError, fn -> Pagination.get_page_count(socket, 5) end
  end

  test "raises without a size" do
    socket = socket() |> mount(page_size: nil) |> run_handle_params(%{}, "http://h/a")

    assert_raise ArgumentError, fn -> Pagination.get_page_size(socket) end
    assert_raise ArgumentError, fn -> Pagination.get_limit(socket) end
    assert_raise ArgumentError, fn -> Pagination.get_offset(socket) end
    assert Pagination.get_offset(socket, 10) == 0
  end

  test "page_to and page_rel_to keep the other params" do
    socket =
      socket()
      |> mount(:default)
      |> run_handle_params(%{"page" => "2"}, "http://h/a?page=2&q=x")

    assert Pagination.page_to(socket, 42) == "/a?page=42&q=x"
    assert Pagination.page_rel_to(socket, 1) == "/a?page=3&q=x"
    assert Pagination.page_rel_to(socket, -1) == "/a?q=x"
    assert Pagination.page_rel_to(socket, -5) == "/a?q=x"
  end

  test "several paginations" do
    socket =
      socket()
      |> mount(key: :users_page, page_param: "up", event: "up")
      |> mount(key: :groups_page, page_param: "gp", event: "gp", page_size: 10)
      |> run_handle_params(%{"up" => "2", "gp" => "3"}, "http://h/a?up=2&gp=3")

    assert %{users_page: %{page: 2, size: 20}, groups_page: %{page: 3, size: 10}} =
             socket.assigns

    assert Pagination.get_offset(socket, :users_page) == 20
    assert Pagination.get_offset(socket, :groups_page) == 20
    assert Pagination.get_limit(socket, :groups_page) == 10
    assert Pagination.get_offset(socket, :groups_page, 5) == 10

    assert Pagination.page_rel_to(socket, :groups_page, 1) == "/a?gp=4&up=2"
    assert Pagination.page_to(socket, :users_page, 1) == "/a?gp=3"

    assert_raise ArgumentError, ~r/not mounted/, fn -> Pagination.get_page(socket) end

    assert_raise ArgumentError, ~r/assign :users_page is already used/, fn ->
      mount(socket, key: :users_page)
    end

    assert_raise ArgumentError, ~r/event "gp" is already used/, fn ->
      mount(socket, key: :x, event: "gp")
    end

    socket =
      LiveReverse.detach(socket, Pagination, key: :users_page, page_param: "up", event: "up")

    assert_raise ArgumentError, ~r/not mounted/, fn ->
      Pagination.get_page(socket, :users_page)
    end

    assert Pagination.get_page(socket, :groups_page) == 3
    assert mount(socket, key: :users_page, event: "up")
  end

  test "page size from a param" do
    socket =
      socket()
      |> mount(key: :users_page, page_param: "up", page_size_param: "up_size", page_size: 10)
      |> run_handle_params(%{"up" => "3"}, "http://h/a?up=3&q=x")

    assert Pagination.get_page_size(socket, :users_page) == 10
    assert Pagination.get_offset(socket, :users_page) == 20

    socket = run_handle_params(socket, %{"up" => "3", "up_size" => "25"}, "http://h/a")
    assert Pagination.get_page_size(socket, :users_page) == 25
    assert socket.assigns.users_page == %{page: 3, size: 25}
    assert Pagination.get_offset(socket, :users_page) == 50

    for bad <- ["", "x", "0", "-1"] do
      socket = run_handle_params(socket, %{"up_size" => bad}, "http://h/a")
      assert Pagination.get_page_size(socket, :users_page) == 10
    end

    socket = run_handle_params(socket, %{"up" => "3"}, "http://h/a?up=3&q=x")
    assert Pagination.page_size_to(socket, :users_page, 25) == "/a?q=x&up_size=25"
    assert Pagination.page_size_to(socket, :users_page, 10) == "/a?q=x"
  end

  test "page_size_to raises without page_size_param" do
    socket = socket() |> mount(:default) |> run_handle_params(%{}, "http://h/a")
    assert_raise ArgumentError, ~r/page_size_param/, fn -> Pagination.page_size_to(socket, 25) end
  end

  test "events patch to a page, a relative page or a size" do
    socket =
      socket()
      |> mount(
        key: :users_page,
        page_param: "up",
        page_size_param: "up_size",
        event: "users_page"
      )
      |> mount(
        key: :groups_page,
        page_param: "gp",
        event: "groups_page",
        event_rel_path: ["nav", "rel"]
      )
      |> run_handle_params(%{"up" => "3", "gp" => "2"}, "http://h/a?up=3&gp=2")

    assert {:halt, s} = run_handle_event(socket, "users_page", %{"page" => "5"})
    assert patched_to(s) == "/a?gp=2&up=5"

    assert {:halt, s} = run_handle_event(socket, "users_page", %{"rel" => "-1"})
    assert patched_to(s) == "/a?gp=2&up=2"

    assert {:halt, s} = run_handle_event(socket, "users_page", %{"rel" => 1})
    assert patched_to(s) == "/a?gp=2&up=4"

    assert {:halt, s} = run_handle_event(socket, "users_page", %{"size" => "50"})
    assert patched_to(s) == "/a?gp=2&up_size=50"

    assert {:halt, s} = run_handle_event(socket, "groups_page", %{"nav" => %{"rel" => "1"}})
    assert patched_to(s) == "/a?gp=3&up=3"

    assert {:halt, s} = run_handle_event(socket, "users_page", %{"page" => "x"})
    assert s.redirected == nil

    assert {:cont, _} = run_handle_event(socket, "other", %{"page" => "5"})
  end

  test "page event by default, nil for none" do
    socket = socket() |> mount(:default) |> run_handle_params(%{}, "http://h/a")
    assert {:halt, s} = run_handle_event(socket, "page", %{"page" => "2"})
    assert patched_to(s) == "/a?page=2"

    socket =
      socket()
      |> mount(event: nil)
      |> mount(key: :other, page_param: "other", event: nil)
      |> run_handle_params(%{}, "http://h/a")

    assert {:cont, _} = run_handle_event(socket, "page", %{"page" => "2"})
  end

  test "raises on a used param or param_size" do
    socket = mount(socket(), page_param: "p", page_size_param: "p_size", event: nil)

    assert_raise ArgumentError, ~r/param "p" is already used/, fn ->
      mount(socket, key: :x, page_param: "p", event: "x")
    end

    assert_raise ArgumentError, ~r/param "p_size" is already used/, fn ->
      mount(socket, key: :x, page_param: "p_size", event: "x")
    end

    assert_raise ArgumentError, ~r/param "y" is already used/, fn ->
      mount(socket(), key: :y, page_param: "y", page_size_param: "y", event: "y")
    end
  end

  test "raises on unknown options" do
    assert_raise ArgumentError, ~r/unknown pagination options \[:param\]/, fn ->
      mount(socket(), param: "p")
    end
  end
end
