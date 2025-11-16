# RouterOS API

[![Hex.pm](https://img.shields.io/hexpm/v/routeros_api.svg)](https://hex.pm/packages/routeros_api)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/routeros_api)

Elixir client for MikroTik RouterOS binary API. Supports both plain TCP (port 8728) and TLS (port 8729) connections.

## Features

- ✅ Plain TCP connections (port 8728)
- ✅ TLS/SSL connections (port 8729)
- ✅ MD5 challenge-response authentication
- ✅ Response parsing to Elixir maps
- ✅ Synchronous command execution
- ✅ Custom port support
- ✅ Certificate verification options
- ✅ Connection pooling with NimblePool
- ✅ Telemetry integration

## Installation

Add `routeros_api` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:routeros_api, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Basic Connection (Plain TCP)

```elixir
# Connect to router
{:ok, conn} = RouterosApi.connect(%{
  host: "192.168.88.1",
  port: 8728,
  username: "admin",
  password: "password"
})

# Execute a command
{:ok, interfaces} = RouterosApi.command(conn, ["/interface/print"])

# Result is a list of maps
[
  %{
    "name" => "ether1",
    "type" => "ether",
    "disabled" => false,
    "running" => true
  },
  ...
]

# Disconnect when done
RouterosApi.disconnect(conn)
```

### Secure Connection (TLS)

```elixir
# Auto-detect TLS from port
{:ok, conn} = RouterosApi.connect(%{
  host: "192.168.88.1",
  port: 8729,  # TLS port
  username: "admin",
  password: "password"
})

# Or explicit TLS connection
{:ok, conn} = RouterosApi.connect_tls(%{
  host: "192.168.88.1",
  port: 8729,
  username: "admin",
  password: "password",
  ssl_opts: [
    verify: :verify_peer,
    cacertfile: "/path/to/ca.pem"
  ]
})
```

### Self-Signed Certificates (Lab/Testing)

```elixir
{:ok, conn} = RouterosApi.connect_tls(%{
  host: "192.168.88.1",
  port: 8729,
  username: "admin",
  password: "password",
  ssl_opts: [
    verify: :verify_none  # NOT recommended for production
  ]
})
```

## Usage Examples

### List IP Addresses

```elixir
{:ok, addresses} = RouterosApi.command(conn, ["/ip/address/print"])
```

### Add IP Address

```elixir
{:ok, _} = RouterosApi.command(conn, [
  "/ip/address/add",
  "=address=192.168.88.2/24",
  "=interface=bridge"
])
```

### Query with Filters

```elixir
{:ok, [interface]} = RouterosApi.command(conn, [
  "/interface/print",
  "?name=ether1"
])
```

### Error Handling

```elixir
case RouterosApi.command(conn, ["/interface/print"]) do
  {:ok, data} ->
    IO.inspect(data)

  {:error, %RouterosApi.Error{type: :trap, message: msg}} ->
    IO.puts("RouterOS error: #{msg}")

  {:error, %RouterosApi.Error{type: :fatal}} ->
    IO.puts("Fatal error - connection lost")

  {:error, reason} ->
    IO.puts("Network error: #{inspect(reason)}")
end
```

## Configuration

### Custom Ports

```elixir
# Custom plain TCP port
{:ok, conn} = RouterosApi.connect_plain(%{
  host: "router.example.com",
  port: 9999,
  username: "admin",
  password: "password"
})

# Custom TLS port
{:ok, conn} = RouterosApi.connect_tls(%{
  host: "router.example.com",
  port: 9998,
  username: "admin",
  password: "password"
})
```

### Timeouts

```elixir
{:ok, conn} = RouterosApi.connect(%{
  host: "192.168.88.1",
  username: "admin",
  password: "password",
  timeout: 10_000  # 10 seconds
})
```

### Connection Pooling

For production use, use connection pooling:

```elixir
# In your application.ex
children = [
  {RouterosApi.Pool, [
    name: :main_router,
    host: "192.168.88.1",
    username: "admin",
    password: "password",
    pool_size: 10
  ]}
]

# In your code
{:ok, interfaces} = RouterosApi.command(:main_router, ["/interface/print"])
```

### Telemetry

The library emits telemetry events for monitoring:

**Connection Events:**
- `[:routeros_api, :connection, :start]` - Connection attempt started
- `[:routeros_api, :connection, :stop]` - Connection successful
- `[:routeros_api, :connection, :exception]` - Connection failed

**Command Events:**
- `[:routeros_api, :command, :start]` - Command execution started
- `[:routeros_api, :command, :stop]` - Command completed successfully
- `[:routeros_api, :command, :exception]` - Command failed

**Pool Events:**
- `[:routeros_api, :pool, :checkout]` - Connection checked out from pool
- `[:routeros_api, :pool, :checkin]` - Connection returned to pool

Example telemetry handler:

```elixir
:telemetry.attach_many(
  "routeros-api-handler",
  [
    [:routeros_api, :command, :stop],
    [:routeros_api, :command, :exception]
  ],
  &MyApp.Telemetry.handle_event/4,
  nil
)

defmodule MyApp.Telemetry do
  require Logger

  def handle_event([:routeros_api, :command, :stop], measurements, metadata, _config) do
    if measurements.duration > 1_000_000_000 do
      Logger.warning("Slow RouterOS command: #{metadata.command} (#{measurements.duration}ns)")
    end
  end

  def handle_event([:routeros_api, :command, :exception], _measurements, metadata, _config) do
    Logger.error("RouterOS command failed: #{metadata.command} - #{inspect(metadata.reason)}")
  end
end
```

### Helper Functions

The library provides convenient helper functions for common operations:

```elixir
alias RouterosApi.Helpers

# List all interfaces
{:ok, interfaces} = Helpers.list_interfaces(conn)

# Get specific interface
{:ok, interface} = Helpers.get_interface(conn, "ether1")

# List IP addresses
{:ok, addresses} = Helpers.list_ip_addresses(conn)

# Add IP address
{:ok, _} = Helpers.add_ip_address(conn, "192.168.1.1/24", "ether1")

# Get system information
{:ok, resource} = Helpers.get_system_resource(conn)

# Get/set router identity
{:ok, identity} = Helpers.get_identity(conn)
{:ok, _} = Helpers.set_identity(conn, "MyRouter")

# List firewall rules
{:ok, rules} = Helpers.list_firewall_rules(conn)

# List DHCP leases
{:ok, leases} = Helpers.list_dhcp_leases(conn)
```

All helpers work with both direct connections and connection pools.

## Documentation

Full documentation is available at [https://hexdocs.pm/routeros_api](https://hexdocs.pm/routeros_api).

## Roadmap

### v0.1.0 (Current - MVP)
- [x] Binary protocol implementation
- [x] TCP and TLS connections
- [x] MD5 authentication
- [x] Response parsing
- [x] Basic documentation

### v1.0.0 (Production Ready)
- [ ] Connection pooling with NimblePool
- [ ] Telemetry integration
- [ ] Helper functions for common operations
- [ ] Comprehensive documentation
- [ ] CI/CD pipeline

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

This project was inspired by the original [erotik](https://github.com/comtihon/erotik) Erlang library.

