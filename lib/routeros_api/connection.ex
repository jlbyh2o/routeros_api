defmodule RouterosApi.Connection do
  @moduledoc """
  GenServer that manages a connection to a MikroTik RouterOS device.

  Handles:
  - TCP or TLS connection establishment
  - Authentication
  - Command execution
  - Connection lifecycle

  ## Configuration

  - `:host` - Router hostname or IP address (required)
  - `:port` - Port number (optional, defaults to 8728 for plain, 8729 for TLS)
  - `:username` - RouterOS username (required)
  - `:password` - RouterOS password (required)
  - `:ssl` - Boolean, use TLS connection (optional, auto-detected from port)
  - `:ssl_opts` - SSL options (optional, e.g., `[verify: :verify_peer]`)
  - `:timeout` - Connection timeout in milliseconds (optional, default: 5000)

  ## Example

      config = %{
        host: "192.168.88.1",
        port: 8728,
        username: "admin",
        password: "password"
      }

      {:ok, pid} = RouterosApi.Connection.start_link(config)
      {:ok, result} = RouterosApi.Connection.command(pid, ["/interface/print"])
  """

  use GenServer
  require Logger

  alias RouterosApi.{Auth, Protocol, Response, Error}

  @default_timeout 5000
  @default_plain_port 8728
  @default_tls_port 8729

  defstruct [
    :socket,
    :host,
    :port,
    :username,
    :password,
    :ssl,
    :ssl_opts,
    :timeout
  ]

  @type t :: %__MODULE__{
          socket: :gen_tcp.socket() | :ssl.sslsocket() | nil,
          host: String.t(),
          port: non_neg_integer(),
          username: String.t(),
          password: String.t(),
          ssl: boolean(),
          ssl_opts: keyword(),
          timeout: non_neg_integer()
        }

  ## Client API

  @doc """
  Starts a connection GenServer.

  ## Options

  See module documentation for available options.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(config) when is_map(config) do
    GenServer.start_link(__MODULE__, config)
  end

  @doc """
  Executes a command on the router.

  Returns `{:ok, result}` or `{:error, reason}`.

  ## Examples

      {:ok, interfaces} = RouterosApi.Connection.command(conn, ["/interface/print"])
  """
  @spec command(GenServer.server(), [String.t()]) :: {:ok, term()} | {:error, term()}
  def command(server, words) when is_list(words) do
    GenServer.call(server, {:command, words}, :infinity)
  end

  @doc """
  Stops the connection.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(server) do
    GenServer.stop(server, :normal)
  end

  ## Server Callbacks

  @impl true
  def init(config) do
    # Parse and validate configuration
    state = parse_config(config)

    # Connect and authenticate
    case connect_and_auth(state) do
      {:ok, socket} ->
        {:ok, %{state | socket: socket}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:command, words}, _from, state) do
    case execute_command(state.socket, words) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    close_socket(state.socket, state.ssl)
    :ok
  end

  ## Private Functions

  defp parse_config(config) do
    host = Map.fetch!(config, :host)
    username = Map.fetch!(config, :username)
    password = Map.fetch!(config, :password)

    port = Map.get(config, :port)
    ssl = Map.get(config, :ssl)
    ssl_opts = Map.get(config, :ssl_opts, [])
    timeout = Map.get(config, :timeout, @default_timeout)

    # Auto-detect SSL from port if not specified
    {port, ssl} =
      cond do
        port && ssl != nil -> {port, ssl}
        port == @default_tls_port -> {port, true}
        port -> {port, false}
        ssl == true -> {@default_tls_port, true}
        true -> {@default_plain_port, false}
      end

    %__MODULE__{
      host: host,
      port: port,
      username: username,
      password: password,
      ssl: ssl,
      ssl_opts: ssl_opts,
      timeout: timeout
    }
  end

  defp connect_and_auth(state) do
    with {:ok, socket} <- establish_connection(state),
         :ok <- Auth.login(socket, state.username, state.password) do
      {:ok, socket}
    else
      {:error, reason} ->
        {:error, Error.new(:connection_failed, "Failed to connect: #{inspect(reason)}")}
    end
  end

  defp establish_connection(%{ssl: true} = state) do
    # TLS connection
    host_charlist = String.to_charlist(state.host)

    opts = [
      :binary,
      {:active, false}
      | state.ssl_opts
    ]

    case :ssl.connect(host_charlist, state.port, opts, state.timeout) do
      {:ok, socket} ->
        {:ok, socket}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp establish_connection(state) do
    # Plain TCP connection
    host_charlist = String.to_charlist(state.host)

    opts = [
      :binary,
      {:active, false}
    ]

    case :gen_tcp.connect(host_charlist, state.port, opts, state.timeout) do
      {:ok, socket} ->
        {:ok, socket}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_command(socket, words) do
    with :ok <- Protocol.write_sentence(socket, words),
         {:ok, sentences} <- Protocol.read_block(socket),
         {:ok, data} <- Response.parse(sentences) do
      {:ok, data}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp close_socket(nil, _ssl), do: :ok

  defp close_socket(socket, true) do
    :ssl.close(socket)
  end

  defp close_socket(socket, false) do
    :gen_tcp.close(socket)
  end
end
