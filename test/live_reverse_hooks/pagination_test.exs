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
      |> mount(key: :p, param: "p")
      |> run_handle_params(%{"p" => "2"}, "http://h/a")

    assert socket.assigns.p == %{page: 2, size: 20}
    assert Pagination.get_page(socket, :p) == 2
  end

  test "size, offset and limit" do
    socket =
      socket()
      |> mount(size: 10)
      |> run_handle_params(%{"page" => "3"}, "http://h/a")

    assert Pagination.get_page_size(socket) == 10
    assert Pagination.get_limit(socket) == 10
    assert Pagination.get_offset(socket) == 20
    assert Pagination.get_limit(socket, 5) == 5
    assert Pagination.get_offset(socket, 5) == 10
  end

  test "raises without a size" do
    socket = socket() |> mount(size: nil) |> run_handle_params(%{}, "http://h/a")

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
      |> mount(key: :users_page, param: "up")
      |> mount(key: :groups_page, param: "gp", size: 10)
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
    assert_raise ArgumentError, ~r/already mounted/, fn -> mount(socket, key: :users_page) end

    socket = LiveReverse.detach(socket, Pagination, key: :users_page, param: "up")

    assert_raise ArgumentError, ~r/not mounted/, fn ->
      Pagination.get_page(socket, :users_page)
    end

    assert Pagination.get_page(socket, :groups_page) == 3
  end

  test "page size from a param" do
    socket =
      socket()
      |> mount(key: :users_page, param: "up", param_size: "up_size", size: 10)
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

  test "page_size_to raises without param_size" do
    socket = socket() |> mount(:default) |> run_handle_params(%{}, "http://h/a")
    assert_raise ArgumentError, ~r/param_size/, fn -> Pagination.page_size_to(socket, 25) end
  end
end
