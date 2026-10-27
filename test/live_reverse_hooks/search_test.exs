defmodule LiveReverseHooks.SearchTest do
  use ExUnit.Case, async: true

  alias LiveReverseHooks.Search
  alias Phoenix.LiveView.{Lifecycle, Socket}

  # handle_params hooks need a socket mounted at a router, any module will do
  defp socket do
    %Socket{router: __MODULE__, private: %{lifecycle: %Lifecycle{}, live_temp: %{}}}
  end

  defp mount(socket, arg) do
    {:cont, socket} = Search.on_mount(arg, %{}, %{}, socket)
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

  test "search event assigns, patches and halts" do
    socket =
      socket()
      |> mount(:default)
      |> run_handle_params(%{}, "http://h/a?b=1")

    assert {:halt, socket} = run_handle_event(socket, "search", %{"search" => "y"})
    assert socket.assigns.search == "y"
    assert {:live, :patch, %{to: to}} = socket.redirected
    assert URI.decode_query(URI.parse(to).query) == %{"b" => "1", "search" => "y"}

    assert {:cont, _} = run_handle_event(socket, "other", %{})
  end

  test "custom options and several entries" do
    socket =
      socket()
      |> mount(:default)
      |> mount(key: :tag_search, param: "q", event: "tag_search", payload_key: "value")
      |> run_handle_params(%{"search" => "a", "q" => "b"}, "http://h/a")

    assert %{search: "a", tag_search: "b"} = socket.assigns

    {:halt, socket} = run_handle_event(socket, "tag_search", %{"value" => "c"})
    assert %{search: "a", tag_search: "c"} = socket.assigns
    assert {:live, :patch, %{to: "/a?q=c"}} = socket.redirected
  end

  test "search?" do
    assert Search.search?("x")
    refute Search.search?("")
    refute Search.search?(nil)
    assert Search.search?(%{search: "x"})
    assert Search.search?(%{q: "x"}, :q)
  end
end
