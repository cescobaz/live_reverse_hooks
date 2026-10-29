defmodule Demo.Words.Word do
  @enforce_keys [:id, :user_id, :text]
  defstruct [:id, :user_id, :text]

  @type t :: %__MODULE__{id: pos_integer(), user_id: String.t(), text: String.t()}
end
