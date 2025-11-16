defmodule RouterosApi.Response do
  @moduledoc """
  Response parsing for MikroTik RouterOS API.

  Converts raw sentence data into Elixir-friendly structures.

  ## Response Format

  RouterOS responses consist of sentences with status words:
  - `!done` - Successful completion
  - `!trap` - Error from RouterOS
  - `!fatal` - Fatal error

  Data attributes are in the format `=key=value`.

  ## Examples

      # Input: [["!done", "=name=ether1", "=type=ether"]]
      # Output: {:ok, [%{"name" => "ether1", "type" => "ether"}]}

      # Input: [["!trap", "=message=no such item"]]
      # Output: {:error, %RouterosApi.Error{type: :trap, message: "no such item"}}
  """

  alias RouterosApi.Error

  @doc """
  Parses a block of sentences into structured data.

  Returns `{:ok, data}` on success or `{:error, error}` on failure.

  ## Examples

      iex> RouterosApi.Response.parse([["!done", "=name=ether1", "=type=ether"]])
      {:ok, [%{"name" => "ether1", "type" => "ether"}]}

      iex> RouterosApi.Response.parse([["!done"]])
      {:ok, []}
  """
  @spec parse([[String.t()]]) :: {:ok, [map()]} | {:error, Error.t()}
  def parse(sentences) when is_list(sentences) do
    # Find the status sentence (last one with !done, !trap, or !fatal)
    {status, data_sentences} = extract_status_and_data(sentences)

    case status do
      :done ->
        data = Enum.map(data_sentences, &parse_sentence/1)
        {:ok, data}

      :trap ->
        error = extract_error(sentences, :trap)
        {:error, error}

      :fatal ->
        error = extract_error(sentences, :fatal)
        {:error, error}

      nil ->
        # No status found, treat as data
        data = Enum.map(sentences, &parse_sentence/1)
        {:ok, data}
    end
  end

  @doc """
  Parses a single sentence into a map.

  Filters out status words and converts attributes to key-value pairs.

  ## Examples

      iex> RouterosApi.Response.parse_sentence(["=name=ether1", "=type=ether"])
      %{"name" => "ether1", "type" => "ether"}

      iex> RouterosApi.Response.parse_sentence(["!done", "=name=value"])
      %{"name" => "value"}
  """
  @spec parse_sentence([String.t()]) :: map()
  def parse_sentence(words) when is_list(words) do
    words
    |> Enum.reject(&status_word?/1)
    |> Enum.map(&parse_attribute/1)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  @doc """
  Parses an attribute string into a {key, value} tuple.

  ## Examples

      iex> RouterosApi.Response.parse_attribute("=name=ether1")
      {"name", "ether1"}

      iex> RouterosApi.Response.parse_attribute("=disabled=false")
      {"disabled", false}

      iex> RouterosApi.Response.parse_attribute("=running=true")
      {"running", true}
  """
  @spec parse_attribute(String.t()) :: {String.t(), term()} | nil
  def parse_attribute("=" <> rest) do
    case String.split(rest, "=", parts: 2) do
      [key, value] ->
        {key, coerce_value(value)}

      [key] ->
        {key, ""}

      _ ->
        nil
    end
  end

  def parse_attribute(_), do: nil

  @doc """
  Coerces string values to appropriate Elixir types.

  ## Examples

      iex> RouterosApi.Response.coerce_value("true")
      true

      iex> RouterosApi.Response.coerce_value("false")
      false

      iex> RouterosApi.Response.coerce_value("yes")
      true

      iex> RouterosApi.Response.coerce_value("no")
      false

      iex> RouterosApi.Response.coerce_value("hello")
      "hello"
  """
  @spec coerce_value(String.t()) :: term()
  def coerce_value("true"), do: true
  def coerce_value("false"), do: false
  def coerce_value("yes"), do: true
  def coerce_value("no"), do: false
  def coerce_value(value), do: value

  @doc """
  Checks if a word is a status word.

  ## Examples

      iex> RouterosApi.Response.status_word?("!done")
      true

      iex> RouterosApi.Response.status_word?("=name=value")
      false
  """
  @spec status_word?(String.t()) :: boolean()
  def status_word?("!" <> _), do: true
  def status_word?(_), do: false

  ## Private Functions

  defp extract_status_and_data(sentences) do
    # Find the last sentence with a status word
    status_sentence =
      sentences
      |> Enum.reverse()
      |> Enum.find(fn sentence ->
        Enum.any?(sentence, &status_word?/1)
      end)

    status = if status_sentence, do: detect_status(status_sentence), else: nil

    # Data sentences are all sentences except pure status sentences
    data_sentences =
      Enum.reject(sentences, fn sentence ->
        # Reject if it's ONLY status words (no data attributes)
        has_status = Enum.any?(sentence, &status_word?/1)
        has_data = Enum.any?(sentence, &String.starts_with?(&1, "="))
        has_status and not has_data
      end)

    {status, data_sentences}
  end

  defp detect_status(sentence) do
    cond do
      Enum.member?(sentence, "!done") -> :done
      Enum.member?(sentence, "!trap") -> :trap
      Enum.member?(sentence, "!fatal") -> :fatal
      # !re means reply/data, not a status
      Enum.member?(sentence, "!re") -> false
      true -> nil
    end
  end

  defp extract_error(sentences, type) do
    # Find error message in sentences
    message =
      sentences
      |> Enum.flat_map(& &1)
      |> Enum.find_value(fn word ->
        case parse_attribute(word) do
          {"message", msg} -> msg
          _ -> nil
        end
      end) || "Unknown error"

    Error.new(type, message)
  end
end
