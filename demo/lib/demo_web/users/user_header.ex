defmodule DemoWeb.Users.UserHeader do
  @moduledoc """
  Renders the top bar with the user id (see `DemoWeb.Users.UserHook`). The
  content, e.g. buttons of the page, follows it.

      <UserHeader.render user_id={@user_id}>
        <button phx-click="reset">Reset words</button>
      </UserHeader.render>
  """
  use Phoenix.Component

  attr :user_id, :string, required: true
  slot :inner_block

  def render(assigns) do
    ~H"""
    <header class="bar">
      <span class="muted">User {@user_id}</span>
      {render_slot(@inner_block)}
    </header>
    """
  end
end
