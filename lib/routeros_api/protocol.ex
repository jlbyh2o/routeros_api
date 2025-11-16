defmodule RouterosApi.Protocol do
  @moduledoc """
  Binary protocol implementation for MikroTik RouterOS API.

  The protocol uses length-encoded words and sentences:
  - Words are length-prefixed strings
  - Sentences are lists of words terminated by an empty word
  - Blocks are lists of sentences

  ## Length Encoding

  Lengths are encoded as follows:
  - `< 0x80` (128): 1 byte
  - `< 0x4000` (16384): 2 bytes, first byte OR with 0x80
  - `< 0x200000` (2097152): 3 bytes, first byte OR with 0xC0
  - `< 0x10000000` (268435456): 4 bytes, first byte OR with 0xE0
  """

  import Bitwise

  @eof ""

  @doc """
  Encodes a length value according to RouterOS API protocol.

  ## Examples

      iex> RouterosApi.Protocol.encode_length(5)
      <<5>>

      iex> RouterosApi.Protocol.encode_length(200)
      <<0x80, 200>>
  """
  @spec encode_length(non_neg_integer()) :: binary()
  def encode_length(len) when len < 0x80 do
    <<len>>
  end

  def encode_length(len) when len < 0x4000 do
    <<0x80 ||| len >>> 8, len &&& 0xFF>>
  end

  def encode_length(len) when len < 0x200000 do
    <<0xC0 ||| len >>> 16, len >>> 8 &&& 0xFF, len &&& 0xFF>>
  end

  def encode_length(len) when len < 0x10000000 do
    <<0xE0 ||| len >>> 24, len >>> 16 &&& 0xFF, len >>> 8 &&& 0xFF, len &&& 0xFF>>
  end

  @doc """
  Decodes a length value from a socket.

  Returns `{:ok, length}` or `{:error, reason}`.
  """
  @spec decode_length(:gen_tcp.socket() | :ssl.sslsocket()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def decode_length(socket) do
    case recv(socket, 1) do
      {:ok, <<first_byte>>} ->
        decode_length_bytes(socket, first_byte)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # 1 byte length (0x00 - 0x7F)
  defp decode_length_bytes(_socket, byte) when byte < 0x80 do
    {:ok, byte}
  end

  # 2 byte length (0x80 - 0xBF)
  defp decode_length_bytes(socket, byte) when byte >= 0x80 and byte < 0xC0 do
    case recv(socket, 1) do
      {:ok, <<second>>} ->
        len = (byte &&& 0x3F) <<< 8 ||| second
        {:ok, len}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # 3 byte length (0xC0 - 0xDF)
  defp decode_length_bytes(socket, byte) when byte >= 0xC0 and byte < 0xE0 do
    case recv(socket, 2) do
      {:ok, <<second, third>>} ->
        len = (byte &&& 0x1F) <<< 16 ||| second <<< 8 ||| third
        {:ok, len}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # 4 byte length (0xE0 - 0xEF)
  defp decode_length_bytes(socket, byte) when byte >= 0xE0 and byte < 0xF0 do
    case recv(socket, 3) do
      {:ok, <<second, third, fourth>>} ->
        len = (byte &&& 0x0F) <<< 24 ||| second <<< 16 ||| third <<< 8 ||| fourth
        {:ok, len}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Writes a word to the socket.

  A word is a length-prefixed string.
  """
  @spec write_word(:gen_tcp.socket() | :ssl.sslsocket(), String.t()) :: :ok | {:error, term()}
  def write_word(socket, word) do
    len = byte_size(word)
    len_encoded = encode_length(len)

    with :ok <- socket_send(socket, len_encoded),
         :ok <- socket_send(socket, word) do
      :ok
    end
  end

  @doc """
  Reads a word from the socket.

  Returns `{:ok, word}` or `{:error, reason}`.
  An empty word (`""`) indicates end of sentence.
  """
  @spec read_word(:gen_tcp.socket() | :ssl.sslsocket()) :: {:ok, String.t()} | {:error, term()}
  def read_word(socket) do
    case decode_length(socket) do
      {:ok, 0} ->
        {:ok, @eof}

      {:ok, len} ->
        recv(socket, len)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Writes a sentence to the socket.

  A sentence is a list of words terminated by an empty word.
  """
  @spec write_sentence(:gen_tcp.socket() | :ssl.sslsocket(), [String.t()]) ::
          :ok | {:error, term()}
  def write_sentence(socket, words) when is_list(words) do
    Enum.reduce_while(words, :ok, fn word, :ok ->
      case write_word(socket, word) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      :ok -> write_word(socket, @eof)
      error -> error
    end
  end

  # Helper to send data (handles both :gen_tcp and :ssl)
  defp socket_send({:sslsocket, _, _} = socket, data), do: :ssl.send(socket, data)
  defp socket_send(socket, data), do: :gen_tcp.send(socket, data)

  @doc """
  Reads a sentence from the socket.

  A sentence is a list of words terminated by an empty word.
  Returns `{:ok, {status, words}}` where status is one of:
  - `:done` - successful completion
  - `:trap` - error from RouterOS
  - `:fatal` - fatal error
  - `false` - more data follows

  ## Examples

      {:ok, {:done, ["!done", "=name=value"]}}
      {:ok, {:trap, ["!trap", "=message=no such item"]}}
  """
  @spec read_sentence(:gen_tcp.socket() | :ssl.sslsocket()) ::
          {:ok, {atom() | false, [String.t()]}} | {:error, term()}
  def read_sentence(socket) do
    read_sentence(socket, [], false)
  end

  defp read_sentence(socket, acc, status) do
    case read_word(socket) do
      {:ok, @eof} ->
        {:ok, {status, Enum.reverse(acc)}}

      {:ok, "!done"} ->
        read_sentence(socket, ["!done" | acc], :done)

      {:ok, "!trap"} ->
        read_sentence(socket, ["!trap" | acc], :trap)

      {:ok, "!fatal"} ->
        read_sentence(socket, ["!fatal" | acc], :fatal)

      {:ok, "!re"} ->
        # !re means "reply" - data follows, not a final status
        read_sentence(socket, ["!re" | acc], false)

      {:ok, word} ->
        read_sentence(socket, [word | acc], status)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Reads a block of sentences from the socket.

  A block consists of multiple sentences, ending when a sentence
  with a status (done/trap/fatal) is received.

  Returns `{:ok, sentences}` where sentences is a list of sentence lists.
  """
  @spec read_block(:gen_tcp.socket() | :ssl.sslsocket()) ::
          {:ok, [[String.t()]]} | {:error, term()}
  def read_block(socket) do
    read_block(socket, [])
  end

  defp read_block(socket, acc) do
    case read_sentence(socket) do
      {:ok, {false, sentence}} ->
        read_block(socket, [sentence | acc])

      {:ok, {_status, sentence}} ->
        {:ok, Enum.reverse([sentence | acc])}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper to receive data (handles both :gen_tcp and :ssl)
  defp recv({:sslsocket, _, _} = socket, len), do: :ssl.recv(socket, len)
  defp recv(socket, len), do: :gen_tcp.recv(socket, len)
end
