# RouterOS API - Architecture Design

## Current Erlang Implementation Analysis

### How It Works Now:

1. **Connection Model:**
   - GenServer per connection (locally registered by name)
   - Synchronous `gen_server:call` for commands
   - Socket stored in GenServer state
   - Blocking I/O (`{active, false}`)

2. **Command Flow:**
   ```
   User → command(RouterName, ["/ip/address/print"])
        → gen_server:call(RouterName, {command, List}, Timeout)
        → write_sentence(Socket, Command)
        → read_block(Socket)  [BLOCKS until complete]
        → Return result
   ```

3. **Response Format:**
   - Sentences: List of words (strings)
   - Blocks: List of sentences
   - Status words: `!done`, `!trap`, `!fatal`
   - Data format: `["=key=value", "=key2=value2"]`

4. **Issues with Current Design:**
   - ❌ Blocking I/O - one command at a time per connection
   - ❌ No connection pooling
   - ❌ Named registration limits flexibility
   - ❌ Raw string responses (not parsed)
   - ❌ No async support
   - ❌ Timeout is global or per-call only

---

## Proposed Phoenix/Elixir Architecture

### Design Goals:
- ✅ Phoenix-friendly (works well with LiveView, Controllers, Contexts)
- ✅ Concurrent command execution
- ✅ Connection pooling for production
- ✅ Structured data responses (maps, not raw strings)
- ✅ Both sync and async APIs
- ✅ Telemetry integration
- ✅ Proper error handling with tagged tuples

### Architecture Layers:

```
┌─────────────────────────────────────────────────────────┐
│  Application Layer (Phoenix Controllers/LiveView)       │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  RouterosApi (Public API)                               │
│  - connect/1, disconnect/1                              │
│  - command/2, command!/2                                │
│  - async_command/2                                      │
│  - Helper functions (get_interfaces, get_ip_addresses)  │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  RouterosApi.Pool (Connection Pooling)                  │
│  - NimblePool or Poolboy                                │
│  - Checkout/checkin connections                         │
│  - Health checks                                        │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  RouterosApi.Connection (GenServer)                     │
│  - Manages single TCP/TLS connection                    │
│  - Handles authentication                               │
│  - Executes commands                                    │
│  - Parses responses                                     │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  RouterosApi.Protocol                                   │
│  - encode_length/1, decode_length/1                     │
│  - write_word/2, read_word/1                            │
│  - write_sentence/2, read_sentence/1                    │
│  - read_block/1                                         │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  :gen_tcp / :ssl (Erlang/OTP)                           │
└─────────────────────────────────────────────────────────┘
```

---

## API Design Options

### Option 1: Connection-Based (Current Erlang Style)
```elixir
# Start a named connection
{:ok, conn} = RouterosApi.connect(%{
  name: :my_router,
  host: "192.168.88.1",
  username: "admin",
  password: "password"
})

# Use the connection
{:ok, interfaces} = RouterosApi.command(:my_router, ["/interface/print"])
```

**Pros:** Simple, familiar
**Cons:** Named processes, no pooling, manual lifecycle management

---

### Option 2: Pool-Based (Recommended for Phoenix)
```elixir
# In application.ex or config
children = [
  {RouterosApi.Pool, [
    name: :router_pool,
    host: "192.168.88.1",
    username: "admin",
    password: "password",
    pool_size: 5
  ]}
]

# In your Phoenix context
defmodule MyApp.Network do
  def list_interfaces do
    RouterosApi.command(:router_pool, ["/interface/print"])
  end
end
```

**Pros:** Production-ready, concurrent, automatic management
**Cons:** Slightly more setup

---

### Option 3: Hybrid (Best of Both)
```elixir
# For one-off connections (testing, scripts)
{:ok, conn} = RouterosApi.connect(%{host: "192.168.88.1", ...})
{:ok, data} = RouterosApi.command(conn, ["/interface/print"])
RouterosApi.disconnect(conn)

# For production (pooled)
# In application.ex
{RouterosApi.Pool, name: :main_router, ...}


---

## Async Command Support

### Use Case: Long-Running Commands
Some RouterOS commands take time (e.g., `/tool/fetch`, `/ping`, `/tool/bandwidth-test`)

### Async API:
```elixir
# Start async command
{:ok, task} = RouterosApi.async_command(conn, ["/ping", "address=8.8.8.8", "count=10"])

# Do other work...

# Wait for result
{:ok, result} = Task.await(task, 30_000)
```

### Streaming API (Future Enhancement):
```elixir
# For commands that return continuous data
stream = RouterosApi.stream_command(conn, ["/interface/monitor-traffic", "interface=ether1"])

stream
|> Stream.take(10)
|> Enum.each(fn packet ->
  IO.inspect(packet)
end)
```

---

## Phoenix Integration Examples

### In a Phoenix Context:
```elixir
defmodule MyApp.Network do
  @pool :main_router

  def list_interfaces do
    case RouterosApi.command(@pool, ["/interface/print"]) do
      {:ok, interfaces} -> {:ok, interfaces}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_interface(name) do
    case RouterosApi.command(@pool, ["/interface/print", "?name=#{name}"]) do
      {:ok, [interface]} -> {:ok, interface}
      {:ok, []} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def disable_interface(name) do
    RouterosApi.command(@pool, [
      "/interface/set",
      "=.id=#{name}",
      "=disabled=yes"
    ])
  end
end
```

### In a LiveView:
```elixir
defmodule MyAppWeb.NetworkLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to telemetry or periodic updates
      :timer.send_interval(5000, self(), :refresh)
    end

    {:ok, load_interfaces(socket)}
  end

  def handle_info(:refresh, socket) do
    {:noreply, load_interfaces(socket)}
  end

  defp load_interfaces(socket) do
    case MyApp.Network.list_interfaces() do
      {:ok, interfaces} ->
        assign(socket, :interfaces, interfaces)
      {:error, _reason} ->
        assign(socket, :interfaces, [])
    end
  end
end
```

### In a Phoenix Controller:
```elixir
defmodule MyAppWeb.InterfaceController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    case MyApp.Network.list_interfaces() do
      {:ok, interfaces} ->
        json(conn, %{data: interfaces})
      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "Router unavailable: #{inspect(reason)}"})
    end
  end
end
```

---

## Telemetry Events

### Proposed Events:
```elixir
# Connection events
[:routeros_api, :connection, :start]
[:routeros_api, :connection, :stop]
[:routeros_api, :connection, :exception]

# Command events
[:routeros_api, :command, :start]
[:routeros_api, :command, :stop]
[:routeros_api, :command, :exception]

# Pool events
[:routeros_api, :pool, :checkout]
[:routeros_api, :pool, :checkin]
```

### Usage in Phoenix:
```elixir
# In application.ex
:telemetry.attach_many(
  "routeros-api-handler",
  [
    [:routeros_api, :command, :stop],
    [:routeros_api, :command, :exception]
  ],
  &MyApp.Telemetry.handle_event/4,
  nil
)

# Track metrics
defmodule MyApp.Telemetry do
  def handle_event([:routeros_api, :command, :stop], measurements, metadata, _config) do
    # Log slow commands
    if measurements.duration > 1_000_000_000 do
      Logger.warning("Slow RouterOS command: #{inspect(metadata.command)}")
    end
  end
end
```

---

## Configuration

### Application Config:
```elixir
# config/runtime.exs
config :my_app, :router,
  host: System.get_env("ROUTER_HOST", "192.168.88.1"),
  port: String.to_integer(System.get_env("ROUTER_PORT", "8728")),
  username: System.get_env("ROUTER_USER", "admin"),
  password: System.get_env("ROUTER_PASS"),
  pool_size: String.to_integer(System.get_env("ROUTER_POOL_SIZE", "5")),
  ssl: System.get_env("ROUTER_SSL", "false") == "true"
```

### In Application Supervisor:
```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    router_config = Application.fetch_env!(:my_app, :router)

    children = [
      MyAppWeb.Endpoint,
      {RouterosApi.Pool, [
        name: :main_router,
        host: router_config[:host],
        port: router_config[:port],
        username: router_config[:username],
        password: router_config[:password],
        pool_size: router_config[:pool_size],
        ssl: router_config[:ssl]
      ]}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

---

## Recommended Implementation Plan

### Phase 1: Core (Minimal Viable)
1. ✅ `RouterosApi.Connection` - Single connection GenServer
2. ✅ `RouterosApi.Protocol` - Binary protocol implementation
3. ✅ `RouterosApi` - Public API with sync commands
4. ✅ Response parsing to maps
5. ✅ Error handling

### Phase 2: Production Ready
6. ✅ `RouterosApi.Pool` - Connection pooling
7. ✅ Telemetry events
8. ✅ Comprehensive tests
9. ✅ Documentation

### Phase 3: Advanced (Optional)
10. ⏸️ Async command support
11. ⏸️ Streaming API
12. ⏸️ Query builder DSL

---

## Decision Points

### 1. Connection Management
**Recommendation:** Hybrid approach
- Support both direct connections and pooled connections
- Default to pooled for production use

### 2. Response Format
**Recommendation:** Parsed maps
- Convert `"=key=value"` to `%{"key" => "value"}`
- Type coercion for common fields (boolean, integer)
- Keep raw option for advanced users

### 3. API Style
**Recommendation:** Elixir-idiomatic
- Tagged tuples: `{:ok, result}` / `{:error, reason}`
- Bang functions: `command!/2` that raises
- Keyword lists for options

### 4. Pooling Library
**Recommendation:** NimblePool
- Modern, maintained
- Good performance
- Simpler than Poolboy

---

## Questions for Review

1. **Connection Model:** Direct, Pooled, or Hybrid?
2. **Response Parsing:** Always parse to maps, or provide raw option?
3. **Async Support:** Include in v1.0 or defer?
4. **Helper Functions:** How many convenience functions? (e.g., `get_interfaces/1`)
5. **Streaming:** Worth implementing for continuous data?



# In code
{:ok, data} = RouterosApi.command(:main_router, ["/interface/print"])
```

**Pros:** Flexibility for all use cases
**Cons:** Two patterns to learn

---

## Response Parsing

### Current (Raw Strings):
```erlang
{done, ["!done", "=.id=*1", "=name=ether1", "=type=ether"]}
```

### Proposed (Structured Data):
```elixir
{:ok, [
  %{
    ".id" => "*1",
    "name" => "ether1",
    "type" => "ether",
    "disabled" => false,
    "running" => true
  }
]}
```

### Error Handling:
```elixir
# Success
{:ok, data}

# Trap (RouterOS error)
{:error, %RouterosApi.Error{
  type: :trap,
  message: "no such item",
  category: 2
}}

# Fatal (connection error)
{:error, %RouterosApi.Error{
  type: :fatal,
  message: "connection lost"
}}

# Network error
{:error, :timeout}
{:error, :closed}
```


