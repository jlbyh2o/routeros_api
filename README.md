# RouterOS API

[![CI](https://github.com/jlbyh2o/routeros_api/actions/workflows/ci.yml/badge.svg)](https://github.com/jlbyh2o/routeros_api/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/routeros_api.svg)](https://hex.pm/packages/routeros_api)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/routeros_api)

Elixir client for MikroTik RouterOS binary API. Supports both plain TCP (port 8728) and TLS (port 8729) connections.

## Features

- ✅ Plain TCP connections (port 8728)
- ✅ TLS/SSL connections (port 8729) with self-signed certificate support
- ✅ RouterOS 7.x authentication (plain text)
- ✅ RouterOS 6.x authentication (MD5 challenge-response fallback)
- ✅ Response parsing to Elixir maps with type coercion
- ✅ Synchronous command execution
- ✅ Query filters support
- ✅ Connection pooling with NimblePool
- ✅ Telemetry integration for monitoring
- ✅ Helper functions for common operations
- ✅ Type-safe with Dialyzer
- ✅ Comprehensive test coverage (109 tests)

## Installation

Add `routeros_api` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:routeros_api, "~> 0.2.0"}
  ]
end
```

Or from GitHub:

```elixir
def deps do
  [
    {:routeros_api, github: "jlbyh2o/routeros_api"}
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
# Auto-detect TLS from port 8729
{:ok, conn} = RouterosApi.connect(%{
  host: "192.168.88.1",
  port: 8729,  # TLS port - auto-detected
  username: "admin",
  password: "password",
  ssl_opts: [verify: :verify_none]  # For self-signed certificates
})

# Or explicit TLS with certificate verification
{:ok, conn} = RouterosApi.connect(%{
  host: "192.168.88.1",
  port: 8729,
  username: "admin",
  password: "password",
  ssl: true,
  ssl_opts: [
    verify: :verify_peer,
    cacertfile: "/path/to/ca.pem"
  ]
})
```

### Self-Signed Certificates

For lab/testing environments with self-signed certificates:

```elixir
{:ok, conn} = RouterosApi.connect(%{
  host: "192.168.88.1",
  port: 8729,
  username: "admin",
  password: "password",
  ssl_opts: [
    verify: :verify_none  # Disables certificate verification
  ]
})
```

**Note:** `verify: :verify_none` should only be used in lab/testing environments. For production, use proper certificates and `verify: :verify_peer`.

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

### Connection Options

All connection options:

```elixir
{:ok, conn} = RouterosApi.connect(%{
  host: "192.168.88.1",        # Required: Router hostname or IP
  port: 8728,                  # Optional: Port (default: 8728 for TCP, 8729 for TLS)
  username: "admin",           # Required: RouterOS username
  password: "password",        # Required: RouterOS password
  timeout: 5000,               # Optional: Connection timeout in ms (default: 5000)
  ssl: false,                  # Optional: Force TLS (auto-detected from port)
  ssl_opts: []                 # Optional: SSL options (e.g., verify: :verify_none)
})
```

### Connection Pooling

For production use with multiple concurrent requests, use connection pooling:

```elixir
# In your application.ex
def start(_type, _args) do
  children = [
    {RouterosApi.Pool, [
      name: :main_router,
      host: "192.168.88.1",
      port: 8729,                    # Optional: Use TLS
      username: "admin",
      password: "password",
      pool_size: 10,                 # Number of connections in pool
      ssl_opts: [verify: :verify_none]  # For self-signed certs
    ]}
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end

# In your code - use pool name instead of connection PID
{:ok, interfaces} = RouterosApi.command(:main_router, ["/interface/print"])
{:ok, resource} = RouterosApi.Helpers.get_system_resource(:main_router)
```

**Benefits of pooling:**
- Handles concurrent requests efficiently
- Automatic connection health checks
- Connection recovery on failures
- Supervised connections

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

## Authentication

The library automatically handles authentication for different RouterOS versions:

### RouterOS 7.x and 6.43+ (Plain Text)

Modern RouterOS versions use plain text authentication:

```elixir
# The library automatically detects and uses plain text auth
{:ok, conn} = RouterosApi.connect(%{
  host: "192.168.88.1",
  username: "admin",
  password: "password"
})
```

### RouterOS pre-6.43 (MD5 Challenge-Response)

Older RouterOS versions use MD5 challenge-response authentication. The library automatically falls back to this method if plain text authentication fails:

```elixir
# Same code works - automatic fallback
{:ok, conn} = RouterosApi.connect(%{
  host: "192.168.88.1",
  username: "admin",
  password: "password"
})
```

**Note:** The authentication method is automatically detected and handled. You don't need to specify which method to use.

## Troubleshooting

### Connection Issues

**"Connection refused"**
- Ensure the API service is enabled on the router: `/ip service print`
- Check that the correct port is being used (8728 for TCP, 8729 for TLS)
- Verify firewall rules allow connections to the API port

**"Authentication failed"**
- Verify username and password are correct
- Check that the user has API access permissions
- For RouterOS 7.x, ensure you're using the correct authentication method (automatic)

**SSL/TLS Certificate Errors**
- For self-signed certificates, use `ssl_opts: [verify: :verify_none]`
- For production, use proper certificates and `verify: :verify_peer`
- Ensure the API-SSL service is enabled: `/ip service print`

### Performance

**Slow Commands**
- Use connection pooling for concurrent requests
- Monitor with telemetry events
- Check network latency to the router

**Connection Timeouts**
- Increase timeout: `timeout: 10_000` (10 seconds)
- Check router CPU usage
- Verify network connectivity

## Documentation

Full documentation is available at [https://hexdocs.pm/routeros_api](https://hexdocs.pm/routeros_api).

## Testing

The library includes comprehensive test coverage:

```bash
# Run unit tests only
mix test

# Run all tests including integration tests
mix test --include integration --include ssl_integration

# Run with coverage
mix test --cover

# Run Dialyzer type checking
mix dialyzer

# Run code quality checks
mix credo --strict
```

**Test Coverage:**
- 109 tests (all passing)
- Unit tests for all modules
- Integration tests with real RouterOS device
- SSL/TLS integration tests
- Connection pooling tests
- Telemetry tests
- Helper function tests

## Compatibility

**Tested with:**
- Elixir 1.14 - 1.18
- OTP 25 - 28
- RouterOS 7.12.1 (stable)
- RouterOS 6.x (MD5 auth fallback)

**Supported RouterOS versions:**
- RouterOS 7.x (plain text authentication)
- RouterOS 6.43+ (plain text authentication)
- RouterOS pre-6.43 (MD5 authentication fallback)

## Development

### Quality Tools

The project uses several tools to maintain code quality:

- **Dialyzer** - Static type checking
- **Credo** - Code quality and consistency
- **ExDoc** - Documentation generation
- **GitHub Actions** - Automated CI/CD

### Running Quality Checks

```bash
# Format code
mix format

# Check formatting
mix format --check-formatted

# Run all quality checks
mix test && mix dialyzer && mix credo
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

This project was inspired by the original [erotik](https://github.com/comtihon/erotik) Erlang library.

