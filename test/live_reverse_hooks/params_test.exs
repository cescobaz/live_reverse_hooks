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
             %{"q" => "x", "page" => "2", extra: 1}

    assert Params.build(socket, %{project_id: "project", query: "y"}) ==
             %{"project_id" => "project", "q" => "y"}

    assert Params.build(socket |> LiveReverse.detach(Params, query: "q", page: "page")) ==
             %{"project_id" => "g1"}
  end

  test "build_to merges the query into the URI, or the one stored by handle_params" do
    assert Params.build_to(%{"q" => "y"}, "http://x/a?q=x&page=2") == "/a?page=2&q=y"
    assert Params.build_to(%{"q" => "y"}, "http://x/a") == "/a?q=y"

    socket =
      socket()
      |> mount(project_id: "project_id")
      |> run_handle_params(%{}, "http://x/g1?page=2")

    assert Params.build_to(%{"q" => "y"}, socket) == "/g1?page=2&q=y"

    assert_raise ArgumentError, ~r/no URI stored/, fn -> Params.build_to(%{}, socket()) end
  end

  test "raises when the same assign key is bound twice" do
    socket = mount(socket(), project_id: "project_id")

    assert_raise ArgumentError, ~r/\[:project_id\] are already bound/, fn ->
      mount(socket, project_id: "id")
    end
  end

  test "rejects bad bindings" do
    assert_raise ArgumentError, ~r/bad param binding/, fn -> mount(socket(), project_id: :id) end

    assert_raise ArgumentError, ~r/non-empty keyword list/, fn ->
      Params.on_mount(["project_id"], %{}, %{}, socket())
    end
  end
end
