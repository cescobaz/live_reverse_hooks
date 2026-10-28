defmodule LiveReverseHooks.ParamsTest do
  use ExUnit.Case, async: true

  alias LiveReverseHooks.Params
  alias Phoenix.LiveView.{Lifecycle, Socket}

  # handle_params hooks need a socket mounted at a router, any module will do
  defp socket do
    %Socket{router: __MODULE__, private: %{lifecycle: %Lifecycle{}, live_temp: %{}}}
  end

  defp mount(socket, bindings) do
    {:cont, socket} = Params.on_mount(bindings, %{}, %{}, socket)
    socket
  end

  defp run_handle_params(socket, params, uri) do
    Enum.reduce(socket.private.lifecycle.handle_params, socket, fn hook, socket ->
      {:cont, socket} = hook.function.(params, uri, socket)
      socket
    end)
  end

  test "merges bindings from several entries and attaches one hook" do
    socket =
      socket()
      |> mount(uri: :uri, project_id: "project_id")
      |> mount(search: "search")

    assert [%{id: Params}] = socket.private.lifecycle.handle_params
    assert %{project_id: nil, search: nil, uri: nil} = socket.assigns

    socket = run_handle_params(socket, %{"project_id" => "g1", "search" => ""}, "http://x/g1")

    assert %{project_id: "g1", search: nil, uri: "http://x/g1"} = socket.assigns
  end

  test "detach keeps the hook until the last bindings are gone" do
    socket =
      socket()
      |> mount(project_id: "project_id")
      |> mount(search: "search")
      |> LiveReverse.detach(Params, search: "search")

    assert [%{id: Params}] = socket.private.lifecycle.handle_params

    socket = run_handle_params(socket, %{"project_id" => "g1", "search" => "x"}, "http://x")
    assert %{project_id: "g1", search: nil} = socket.assigns

    socket = LiveReverse.detach(socket, Params, project_id: "project_id")
    assert socket.private.lifecycle.handle_params == []
  end

  test "build makes params from the assigns, merged and keyed by param name" do
    socket =
      socket()
      |> mount(uri: :uri, project_id: "project_id")
      |> mount(query: "q", page: "page")
      |> run_handle_params(%{"project_id" => "g1", "q" => "x"}, "http://x")

    assert Params.build(socket) == %{"project_id" => "g1", "q" => "x"}

    assert Params.build(socket, project_id: nil, page: "2", extra: 1) ==
             %{"q" => "x", "page" => "2"}

    assert Params.build(socket, %{project_id: "project", query: "y"}) ==
             %{"project_id" => "project", "q" => "y"}

    assert Params.build(socket, [project_id: nil], keep_nil: true) ==
             %{"project_id" => nil, "q" => "x", "page" => nil}

    assert Params.build(socket |> LiveReverse.detach(Params, query: "q", page: "page")) ==
             %{"project_id" => "g1"}
  end

  test "path params are assigned but not built, query params are both" do
    socket =
      socket()
      |> mount(project_id: {:path, "id"}, page: {:query, "page"}, q: "q")
      |> run_handle_params(%{"id" => "g1", "page" => "2", "q" => ""}, "http://x/g1?page=2&q=")

    assert %{project_id: "g1", page: "2", q: nil} = socket.assigns
    assert Params.build(socket) == %{"page" => "2"}
    assert Params.build(socket, q: "x") |> Params.build_to(socket) == "/g1?page=2&q=x"
  end

  test "build_to sets the query of the URI, or the one stored by handle_params" do
    assert Params.build_to(%{"q" => "y", "page" => nil}, "http://x/a?q=x&page=2") == "/a?q=y"
    assert Params.build_to(%{}, "http://x/a?q=x") == "/a"

    assert Params.build_to(%{"q" => "y"}, "http://x/a?q=x&page=2", mode: :merge) ==
             "/a?page=2&q=y"

    assert Params.build_to(%{"page" => nil}, "http://x/a?q=x&page=2", mode: :merge) == "/a?q=x"
    assert Params.build_to(%{"q" => "y"}, "http://x/a", mode: :merge) == "/a?q=y"

    socket =
      socket()
      |> mount(project_id: "project_id")
      |> run_handle_params(%{}, "http://x/g1?page=2")

    assert Params.build_to(%{"q" => "y"}, socket) == "/g1?q=y"
    assert Params.build_to(%{"q" => "y"}, socket, mode: :merge) == "/g1?page=2&q=y"

    assert_raise ArgumentError, ~r/no URI stored/, fn -> Params.build_to(%{}, socket()) end
  end

  test "raises on a used assign key or query param, also of another hook" do
    socket = mount(socket(), project_id: "project_id", id: {:path, "id"})

    assert_raise ArgumentError, ~r/assign :project_id is already used/, fn ->
      mount(socket, project_id: "other")
    end

    assert_raise ArgumentError, ~r/param "project_id" is already used/, fn ->
      mount(socket, other: "project_id")
    end

    assert_raise ArgumentError, ~r/param "project_id" is already used/, fn ->
      LiveReverseHooks.Pagination.on_mount([page_param: "project_id"], %{}, %{}, socket)
    end

    # path params don't share the query
    assert mount(socket, other: "id")

    socket = LiveReverse.detach(socket, Params, project_id: "project_id", id: {:path, "id"})
    assert mount(socket, project_id: "project_id")
  end

  test "build keeps the params of the other hooks" do
    {:cont, socket} =
      LiveReverseHooks.Pagination.on_mount([page_param: "p"], %{}, %{}, mount(socket(), q: "q"))

    socket = run_handle_params(socket, %{"q" => "x", "p" => "3"}, "http://x/a?q=x&p=3&utm=1")

    assert Params.build(socket, q: "y") == %{"q" => "y", "p" => "3"}
    assert Params.build(socket, q: nil) |> Params.build_to(socket) == "/a?p=3"
    assert Params.build(socket, [q: "y"], keep_others: false) == %{"q" => "y"}
  end

  test "rejects bad bindings" do
    assert_raise ArgumentError, ~r/bad param binding/, fn -> mount(socket(), project_id: :id) end

    assert_raise ArgumentError, ~r/bad param binding/, fn ->
      mount(socket(), project_id: {:body, "id"})
    end

    assert_raise ArgumentError, ~r/non-empty keyword list/, fn ->
      Params.on_mount(["project_id"], %{}, %{}, socket())
    end
  end
end
