defmodule RouterosApi do
  @moduledoc """
  Elixir client for MikroTik RouterOS binary API.

  This module provides the main public API for connecting to and
  communicating with MikroTik RouterOS devices.

  ## Features

  - Plain TCP connections (port 8728)
  - TLS/SSL connections (port 8729)
  - MD5 challenge-response authentication
  - Response parsing to Elixir maps
  - Synchronous command execution

  ## Quick Start

      # Connect to router
      {:ok, conn} = RouterosApi.connect(%{
        host: "192.168.88.1",
        username: "admin",
        password: "password"
      })

      # Execute a command
      {:ok, interfaces} = RouterosApi.command(conn, ["/interface/print"])

      # Disconnect
      RouterosApi.disconnect(conn)

  ## Configuration

  Connection configuration accepts the following options:

  - `:host` - Router hostname or IP address (required)
  - `:port` - Port number (optional, defaults to 8728 for plain, 8729 for TLS)
  - `:username` - RouterOS username (required)
  - `:password` - RouterOS password (required)
  - `:ssl` - Boolean, use TLS connection (optional, auto-detected from port)
  - `:ssl_opts` - SSL options (optional, e.g., `[verify: :verify_peer]`)
  - `:timeout` - Connection timeout in milliseconds (optional, default: 5000)

  ## Examples

  ### Plain TCP Connection

      {:ok, conn} = RouterosApi.connect(%{
        host: "192.168.88.1",
        port: 8728,
        username: "admin",
        password: "password"
      })

  ### TLS Connection

      {:ok, conn} = RouterosApi.connect_tls(%{
        host: "192.168.88.1",
        port: 8729,
        username: "admin",
        password: "password",
        ssl_opts: [verify: :verify_peer]
      })

  ### Execute Commands

      # List interfaces
      {:ok, interfaces} = RouterosApi.command(conn, ["/interface/print"])

      # Add IP address
      {:ok, _} = RouterosApi.command(conn, [
        "/ip/address/add",
        "=address=192.168.88.2/24",
        "=interface=bridge"
      ])

      # Query with filter
      {:ok, [interface]} = RouterosApi.command(conn, [
        "/interface/print",
        "?name=ether1"
      ])
  """

  alias RouterosApi.{Connection, Pool}

  @type connection :: pid() | atom()
  @type config :: %{
          required(:host) => String.t(),
          required(:username) => String.t(),
          required(:password) => String.t(),
          optional(:port) => non_neg_integer(),
          optional(:ssl) => boolean(),
          optional(:ssl_opts) => keyword(),
          optional(:timeout) => non_neg_integer()
        }

  @doc """
  Connects to a MikroTik RouterOS device.

  Auto-detects whether to use TLS based on the port number.
  Port 8729 will use TLS, all other ports will use plain TCP.

  Returns `{:ok, connection}` on success or `{:error, reason}` on failure.

  ## Examples

      # Plain TCP (auto-detected)
      {:ok, conn} = RouterosApi.connect(%{
        host: "192.168.88.1",
        username: "admin",
        password: "password"
      })

      # TLS (auto-detected from port)
      {:ok, conn} = RouterosApi.connect(%{
        host: "192.168.88.1",
        port: 8729,
        username: "admin",
        password: "password"
      })
  """
  @spec connect(config()) :: {:ok, connection()} | {:error, term()}
  def connect(config) when is_map(config) do
    Connection.start_link(config)
  end

  @doc """
  Connects to a MikroTik RouterOS device using plain TCP.

  Forces a plain TCP connection regardless of port number.

  Returns `{:ok, connection}` on success or `{:error, reason}` on failure.

  ## Examples

      {:ok, conn} = RouterosApi.connect_plain(%{
        host: "192.168.88.1",
        port: 8728,
        username: "admin",
        password: "password"
      })
  """
  @spec connect_plain(config()) :: {:ok, connection()} | {:error, term()}
  def connect_plain(config) when is_map(config) do
    config = Map.put(config, :ssl, false)
    Connection.start_link(config)
  end

  @doc """
  Connects to a MikroTik RouterOS device using TLS.

  Forces a TLS connection regardless of port number.

  Returns `{:ok, connection}` on success or `{:error, reason}` on failure.

  ## Examples

      {:ok, conn} = RouterosApi.connect_tls(%{
        host: "192.168.88.1",
        port: 8729,
        username: "admin",
        password: "password",
        ssl_opts: [verify: :verify_peer]
      })
  """
  @spec connect_tls(config()) :: {:ok, connection()} | {:error, term()}
  def connect_tls(config) when is_map(config) do
    config = Map.put(config, :ssl, true)
    Connection.start_link(config)
  end

  @doc """
  Disconnects from the RouterOS device.

  Returns `:ok`.

  ## Examples

      RouterosApi.disconnect(conn)
  """
  @spec disconnect(connection()) :: :ok
  def disconnect(conn) do
    Connection.stop(conn)
  end

  @doc """
  Executes a command on the RouterOS device.

  Commands are specified as a list of words (strings).
  Returns `{:ok, data}` on success or `{:error, reason}` on failure.

  Accepts either a connection PID or a pool name (atom).

  ## Examples

      # With direct connection
      {:ok, conn} = RouterosApi.connect(%{...})
      {:ok, interfaces} = RouterosApi.command(conn, ["/interface/print"])

      # With connection pool
      {:ok, interfaces} = RouterosApi.command(:my_pool, ["/interface/print"])

      # Get specific interface
      {:ok, [interface]} = RouterosApi.command(conn, [
        "/interface/print",
        "?name=ether1"
      ])

      # Add IP address
      {:ok, _} = RouterosApi.command(conn, [
        "/ip/address/add",
        "=address=192.168.88.2/24",
        "=interface=bridge"
      ])
  """
  @spec command(connection(), [String.t()]) :: {:ok, [map()]} | {:error, term()}
  def command(conn, words) when is_pid(conn) and is_list(words) do
    Connection.command(conn, words)
  end

  def command(pool_name, words) when is_atom(pool_name) and is_list(words) do
    Pool.command(pool_name, words)
  end

  @doc """
  Executes a command on the RouterOS device, raising on error.

  Similar to `command/2` but raises a `RouterosApi.Error` exception
  on failure instead of returning an error tuple.

  Returns the data directly on success.

  ## Examples

      interfaces = RouterosApi.command!(conn, ["/interface/print"])
  """
  @spec command!(connection(), [String.t()]) :: [map()]
  def command!(conn, words) when is_list(words) do
    case command(conn, words) do
      {:ok, data} -> data
      {:error, error} -> raise error
    end
  end
end
