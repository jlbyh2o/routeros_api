defmodule RouterosApi.Error do
  @moduledoc """
  Error struct for RouterOS API errors.

  ## Error Types

  - `:trap` - Error from RouterOS (e.g., invalid command, permission denied)
  - `:fatal` - Fatal error from RouterOS (connection will be closed)
  - `:timeout` - Network timeout
  - `:closed` - Connection closed
  - `:auth_failed` - Authentication failed
  - `:connection_failed` - Failed to establish connection
  """

  @type error_type ::
          :trap | :fatal | :timeout | :closed | :auth_failed | :connection_failed

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          details: map()
        }

  defexception [:type, :message, :details]

  @doc """
  Creates a new error struct.

  ## Examples

      iex> RouterosApi.Error.new(:trap, "no such item")
      %RouterosApi.Error{type: :trap, message: "no such item", details: %{}}

      iex> RouterosApi.Error.new(:timeout, "Connection timed out", %{timeout: 5000})
      %RouterosApi.Error{type: :timeout, message: "Connection timed out", details: %{timeout: 5000}}
  """
  @spec new(error_type(), String.t(), map()) :: t()
  def new(type, message, details \\ %{}) do
    %__MODULE__{
      type: type,
      message: message,
      details: details
    }
  end

  @doc """
  Implements the Exception behaviour message callback.
  """
  @impl true
  def message(%__MODULE__{type: type, message: msg}) do
    "RouterOS API Error (#{type}): #{msg}"
  end
end

