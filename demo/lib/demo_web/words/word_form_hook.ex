defmodule DemoWeb.Words.WordFormHook do
  @moduledoc """
  A form that adds a word to the user of the `:user_key` assign.

  It assigns the form to `:form_key`. On the submit event it creates the
  word with `Demo.Words.create/1` and clears the form, or keeps it with
  the error on the `text` field; the validate event clears it. The
  `Demo.Words` events reload the list (see `DemoWeb.Words.WordsHook`).

      on_mount DemoWeb.Words.WordFormHook

      <DemoWeb.Words.WordForm.render form={@form} />

  ## Options

    * `:user_key` - the assign with the user id. Defaults to `:user_id`.
    * `:form_key` - the assign with the form. Defaults to `:form`.
    * `:validate_event` - the `phx-change` event. Defaults to `"validate"`.
    * `:submit_event` - the `phx-submit` event. Defaults to `"submit"`.
  """
  use LiveReverse
  alias Demo.Words

  @defaults [
    user_key: :user_id,
    form_key: :form,
    validate_event: "validate",
    submit_event: "submit"
  ]

  @impl true
  def mount(arg, _params, _session, socket) do
    opts = opts(arg)
    {:cont, assign_form(socket, opts, %{"text" => ""})}
  end

  @impl true
  def handle_event(arg, event, params, socket) do
    opts = opts(arg)

    cond do
      event == opts[:validate_event] ->
        {:halt, assign_form(socket, opts, params)}

      event == opts[:submit_event] ->
        attrs = %{user_id: socket.assigns[opts[:user_key]], text: params["text"]}

        case Words.create(attrs) do
          {:ok, _word} ->
            {:halt, assign_form(socket, opts, %{"text" => ""})}

          {:error, :unprocessable_entity} ->
            errors = [text: {"Empty or existing word.", []}]
            {:halt, assign_form(socket, opts, params, errors)}
        end

      true ->
        {:cont, socket}
    end
  end

  defp assign_form(socket, opts, params, errors \\ []),
    do: assign(socket, opts[:form_key], Phoenix.Component.to_form(params, errors: errors))

  defp opts(:default), do: @defaults
  defp opts(opts) when is_list(opts), do: Keyword.validate!(opts, @defaults)
end
