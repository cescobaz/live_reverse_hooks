defmodule DemoWeb.Components.SearchForm do
  @moduledoc """
  Renders the search input of a `LiveReverseHooks.Search`. The event and
  the input name default to the ones of the hook; pass the hook's
  `:event` and `:event_search_path` (a plain key) if changed.

      <SearchForm.render search={@search} />
  """
  use Phoenix.Component

  attr :search, :string, default: nil, doc: "the search text, nil for none"
  attr :id, :string, default: "search"
  attr :event, :string, default: "search"
  attr :name, :string, default: "search"
  attr :placeholder, :string, default: "Search"

  def render(assigns) do
    ~H"""
    <form id={@id} phx-change={@event} phx-submit={@event}>
      <input
        type="search"
        name={@name}
        value={@search}
        placeholder={@placeholder}
        phx-debounce="300"
      />
    </form>
    """
  end
end
