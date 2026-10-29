defmodule DemoWeb.Words.WordForm do
  @moduledoc """
  Renders the form that adds a word, the one of
  `DemoWeb.Words.WordFormHook`, with the errors of its `text` field. The
  events default to the ones of the hook; pass the hook's
  `:validate_event` and `:submit_event` if changed.

      <WordForm.render form={@form} />
  """
  use Phoenix.Component

  attr :form, Phoenix.HTML.Form, required: true
  attr :id, :string, default: "word_form"
  attr :validate_event, :string, default: "validate"
  attr :submit_event, :string, default: "submit"

  def render(assigns) do
    ~H"""
    <.form for={@form} id={@id} phx-change={@validate_event} phx-submit={@submit_event}>
      <input type="text" name="text" value={@form[:text].value} placeholder="New word" />
      <button>Add</button>
    </.form>
    <p :for={{message, _opts} <- @form[:text].errors} class="error">{message}</p>
    """
  end
end
