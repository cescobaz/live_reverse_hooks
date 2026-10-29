defmodule DemoWeb.Words.WordList do
  @moduledoc """
  Renders a list of words, each with the delete button of
  `DemoWeb.Words.WordDeleteHook`. The event defaults to the one of the
  hook; pass the hook's `:event` if changed.

      <WordList.render words={@words} />
  """
  use Phoenix.Component

  attr :words, :list, required: true
  attr :delete_event, :string, default: "delete"

  def render(assigns) do
    ~H"""
    <ul>
      <li :for={word <- @words} id={"word-#{word.id}"}>
        {word.text}
        <button phx-click={@delete_event} phx-value-id={word.id}>Delete</button>
      </li>
    </ul>
    <p :if={@words == []} class="muted">No words.</p>
    """
  end
end
