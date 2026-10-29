defmodule Demo.Words.Query do
  @moduledoc """
  The params of `Demo.Words.list/1` and `Demo.Words.count/1`.

  `validate/1` keeps the known keys only and requires `:user_id`, so a
  query never reads the words of another user.
  """
  defstruct user_id: nil, search: nil, offset: 0, limit: nil

  @type t :: %__MODULE__{
          user_id: String.t(),
          search: String.t() | nil,
          offset: non_neg_integer(),
          limit: pos_integer() | nil
        }

  def validate(%__MODULE__{} = query), do: {:ok, query}

  def validate(%{} = params) do
    query = %__MODULE__{
      user_id: params[:user_id],
      search: params[:search],
      offset: params[:offset] || 0,
      limit: params[:limit]
    }

    cond do
      not is_binary(query.user_id) ->
        {:error, :unprocessable_entity}

      not (is_nil(query.search) or is_binary(query.search)) ->
        {:error, :unprocessable_entity}

      not (is_integer(query.offset) and query.offset >= 0) ->
        {:error, :unprocessable_entity}

      not (is_nil(query.limit) or (is_integer(query.limit) and query.limit > 0)) ->
        {:error, :unprocessable_entity}

      true ->
        {:ok, query}
    end
  end
end
