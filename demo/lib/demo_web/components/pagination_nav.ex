defmodule DemoWeb.Components.PaginationNav do
  @moduledoc """
  Renders the previous and next buttons of a
  `LiveReverseHooks.Pagination`, with the current page and the number of
  pages (see `LiveReverseHooks.Pagination.get_page_count/3`). The content,
  if any, follows the page label. The event defaults to the one of the
  hook; pass the hook's `:event` if changed.

      <PaginationNav.render page={@page.page} pages={@pages}>
        ({@count} words)
      </PaginationNav.render>
  """
  use Phoenix.Component

  attr :page, :integer, required: true
  attr :pages, :integer, required: true
  attr :event, :string, default: "page"
  slot :inner_block

  def render(assigns) do
    ~H"""
    <nav>
      <button phx-click={@event} phx-value-rel="-1" disabled={@page <= 1}>Previous</button>
      <span>Page {@page} of {@pages} {render_slot(@inner_block)}</span>
      <button phx-click={@event} phx-value-rel="1" disabled={@page >= @pages}>Next</button>
    </nav>
    """
  end
end
