defmodule RouterosApi.Pool do
  @moduledoc """
  Connection pool for RouterOS API connections using NimblePool.

  Provides efficient connection pooling for production use, allowing
  multiple concurrent requests to share a pool of connections.

  ## Usage

  Add to your application supervision tree:

      children = [
        {RouterosApi.Pool, [
          name: :my_router_pool,
          host: "192.168.88.1",
          username: "admin",
          password: "password",
          pool_size: 5
        ]}
      ]

  Then use the pool name with RouterosApi functions:

      {:ok, interfaces} = RouterosApi.command(:my_router_pool, ["/interface/print"])

  ## Configuration

  - `:name` - Pool name (required, must be an atom)
  - `:host` - Router hostname or IP (required)
  - `:port` - Port number (optional, default: 8728)
  - `:username` - RouterOS username (required)
  - `:password` - RouterOS password (required)
  - `:pool_size` - Number of connections in pool (optional, default: 5)
  - `:ssl` - Use TLS (optional, auto-detected from port)
  - `:ssl_opts` - SSL options (optional)
  - `:timeout` - Connection timeout (optional, default: 5000)
  """

  @behaviour NimblePool

  alias RouterosApi.Connection

  @default_pool_size 5

  @doc """
  Returns a child specification for starting the pool under a supervisor.
  """
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Starts a connection pool.

  ## Options

  See module documentation for available options.

  ## Examples

      {:ok, _pid} = RouterosApi.Pool.start_link(
        name: :my_pool,
        host: "192.168.88.1",
        username: "admin",
        password: "password",
        pool_size: 10
      )
  """
  def start_link(opts) do
    # Extract pool-specific options
    name = Keyword.fetch!(opts, :name)
    pool_size = Keyword.get(opts, :pool_size, @default_pool_size)

    # Connection config (remove pool-specific keys)
    conn_config =
      opts
      |> Keyword.delete(:name)
      |> Keyword.delete(:pool_size)
      |> Map.new()

    # NimblePool options
    pool_opts = [
      worker: {__MODULE__, conn_config},
      pool_size: pool_size,
      name: name
    ]

    NimblePool.start_link(pool_opts)
  end

  @doc """
  Executes a command using a connection from the pool.

  ## Examples

      {:ok, result} = RouterosApi.Pool.command(:my_pool, ["/interface/print"])
  """
  def command(pool_name, words) when is_atom(pool_name) and is_list(words) do
    start_time = System.monotonic_time()

    metadata = %{
      pool: pool_name,
      command: List.first(words)
    }

    :telemetry.execute([:routeros_api, :pool, :checkout], %{system_time: System.system_time()}, metadata)

    result =
      NimblePool.checkout!(
        pool_name,
        :checkout,
        fn _from, conn ->
          result = Connection.command(conn, words)
          {result, conn}
        end
      )

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:routeros_api, :pool, :checkin],
      %{duration: duration},
      metadata
    )

    result
  end

  ## NimblePool Callbacks

  @impl NimblePool
  def init_pool(conn_config) do
    {:ok, conn_config}
  end

  @impl NimblePool
  def init_worker(conn_config) do
    # Start a connection
    case Connection.start_link(conn_config) do
      {:ok, conn} ->
        {:ok, conn, conn_config}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, conn, conn_config) do
    # Check if connection is still alive
    if Process.alive?(conn) do
      {:ok, conn, conn, conn_config}
    else
      # Connection died, create a new one
      case Connection.start_link(conn_config) do
        {:ok, new_conn} ->
          {:ok, new_conn, new_conn, conn_config}

        {:error, reason} ->
          {:remove, reason, conn_config}
      end
    end
  end

  @impl NimblePool
  def handle_checkin(_client_state, _from, conn, conn_config) do
    # Connection is being returned to pool
    if Process.alive?(conn) do
      {:ok, conn, conn_config}
    else
      # Connection died, remove it
      {:remove, :dead, conn_config}
    end
  end

  @impl NimblePool
  def terminate_worker(_reason, conn, conn_config) do
    # Clean up connection
    if Process.alive?(conn) do
      Connection.stop(conn)
    end

    {:ok, conn_config}
  end
end

