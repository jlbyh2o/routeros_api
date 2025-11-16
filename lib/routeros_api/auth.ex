defmodule RouterosApi.Auth do
  @moduledoc """
  Authentication module for MikroTik RouterOS API.

  Implements MD5 challenge-response authentication as required by RouterOS.

  ## Authentication Flow

  1. Send `/login` command
  2. Receive response with salt (`=ret=<hex_salt>`)
  3. Calculate MD5 hash: `md5(0x00 + password + hex_to_binary(salt))`
  4. Send `/login` with username and hashed response
  5. Expect `!done` response

  ## Example

      {:ok, socket} = :gen_tcp.connect('192.168.88.1', 8728, [:binary, active: false])
      :ok = RouterosApi.Auth.login(socket, "admin", "password")
  """

  alias RouterosApi.Protocol

  @doc """
  Performs login authentication on the given socket.

  Returns `:ok` on success or `{:error, reason}` on failure.

  ## Parameters

  - `socket` - The TCP or SSL socket
  - `username` - RouterOS username
  - `password` - RouterOS password

  ## Examples

      {:ok, socket} = :gen_tcp.connect('192.168.88.1', 8728, [:binary, active: false])
      :ok = RouterosApi.Auth.login(socket, "admin", "password")
  """
  @spec login(:gen_tcp.socket() | :ssl.sslsocket(), String.t(), String.t()) ::
          :ok | {:error, term()}
  def login(socket, username, password) do
    # RouterOS 6.43+ uses plain text authentication
    # Try new method first (post-6.43)
    case login_plain(socket, username, password) do
      :ok ->
        :ok

      {:error, _} ->
        # Fall back to old MD5 method (pre-6.43)
        login_md5(socket, username, password)
    end
  end

  @doc """
  Login using plain text password (RouterOS 6.43+).
  """
  @spec login_plain(:gen_tcp.socket() | :ssl.sslsocket(), String.t(), String.t()) ::
          :ok | {:error, term()}
  def login_plain(socket, username, password) do
    sentence = [
      "/login",
      "=name=#{username}",
      "=password=#{password}"
    ]

    with :ok <- Protocol.write_sentence(socket, sentence),
         {:ok, login_response} <- Protocol.read_block(socket),
         :ok <- verify_login_success(login_response) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Login using MD5 challenge-response (RouterOS pre-6.43).
  """
  @spec login_md5(:gen_tcp.socket() | :ssl.sslsocket(), String.t(), String.t()) ::
          :ok | {:error, term()}
  def login_md5(socket, username, password) do
    # Step 1: Send /login command
    with :ok <- Protocol.write_sentence(socket, ["/login"]),
         # Step 2: Read response to get salt
         {:ok, sentences} <- Protocol.read_block(socket),
         {:ok, salt} <- extract_salt(sentences),
         # Step 3: Calculate hash
         hash <- calculate_hash(password, salt),
         # Step 4: Send login with credentials
         :ok <- send_login_credentials(socket, username, hash),
         # Step 5: Read and verify login response
         {:ok, login_response} <- Protocol.read_block(socket),
         :ok <- verify_login_success(login_response) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end


  # Verifies that the login was successful.
  # Checks for !done (success) or !trap (failure).
  @spec verify_login_success([[String.t()]]) :: :ok | {:error, term()}
  defp verify_login_success(sentences) do
    # Check if any sentence has !done
    has_done =
      Enum.any?(sentences, fn sentence ->
        Enum.member?(sentence, "!done")
      end)

    # Check if any sentence has !trap
    has_trap =
      Enum.any?(sentences, fn sentence ->
        Enum.member?(sentence, "!trap")
      end)

    cond do
      has_done ->
        :ok

      has_trap ->
        # Extract error message
        message =
          sentences
          |> Enum.flat_map(& &1)
          |> Enum.find_value(fn word ->
            case String.split(word, "=", parts: 3) do
              ["", "message", msg] -> msg
              _ -> nil
            end
          end) || "Authentication failed"

        {:error, {:auth_failed, message}}

      true ->
        {:error, :unknown_login_response}
    end
  end


  @doc """
  Extracts the salt from the login response.

  The salt is returned in the format `=ret=<hex_salt>`.
  """
  @spec extract_salt([[String.t()]]) :: {:ok, String.t()} | {:error, term()}
  def extract_salt(sentences) do
    # Find the sentence with !done status
    done_sentence =
      Enum.find(sentences, fn sentence ->
        Enum.any?(sentence, &(&1 == "!done"))
      end)

    case done_sentence do
      nil ->
        {:error, :no_done_response}

      sentence ->
        # Find the =ret= attribute
        ret_attr =
          Enum.find(sentence, fn word ->
            String.starts_with?(word, "=ret=")
          end)

        case ret_attr do
          "=ret=" <> salt ->
            {:ok, salt}

          nil ->
            # No salt means new RouterOS version or already authenticated
            {:ok, ""}

          _ ->
            {:error, :invalid_salt_format}
        end
    end
  end

  @doc """
  Calculates the MD5 hash for authentication.

  The hash is calculated as: `md5(0x00 + password + hex_to_binary(salt))`
  and returned as a hex string.
  """
  @spec calculate_hash(String.t(), String.t()) :: String.t()
  def calculate_hash(password, salt) do
    # Convert hex salt to binary
    salt_binary = hex_to_binary(salt)

    # Concatenate: 0x00 + password + salt_binary
    data = <<0>> <> password <> salt_binary

    # Calculate MD5 hash
    hash = :crypto.hash(:md5, data)

    # Convert to hex string
    binary_to_hex(hash)
  end

  @doc """
  Sends the login credentials to the router.
  """
  @spec send_login_credentials(:gen_tcp.socket() | :ssl.sslsocket(), String.t(), String.t()) ::
          :ok | {:error, term()}
  def send_login_credentials(socket, username, hash) do
    sentence = [
      "/login",
      "=name=#{username}",
      "=response=00#{hash}"
    ]

    Protocol.write_sentence(socket, sentence)
  end

  # Converts a hex string to binary
  @spec hex_to_binary(String.t()) :: binary()
  defp hex_to_binary(""), do: <<>>

  defp hex_to_binary(hex_string) do
    # Split into pairs of characters
    hex_string
    |> String.graphemes()
    |> Enum.chunk_every(2)
    |> Enum.map(fn pair ->
      pair
      |> Enum.join()
      |> String.to_integer(16)
    end)
    |> :binary.list_to_bin()
  end

  # Converts binary to hex string
  @spec binary_to_hex(binary()) :: String.t()
  defp binary_to_hex(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map_join(fn byte ->
      byte
      |> Integer.to_string(16)
      |> String.pad_leading(2, "0")
      |> String.downcase()
    end)
  end
end
