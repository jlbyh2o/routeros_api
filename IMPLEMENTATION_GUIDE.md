# RouterOS API - Implementation Quick Reference

## Phase 1: MVP Implementation

### Module Structure

```
lib/
├── routeros_api.ex                    # Public API
├── routeros_api/
│   ├── application.ex                 # Application supervisor
│   ├── connection.ex                  # GenServer for connections
│   ├── protocol.ex                    # Binary protocol implementation
│   ├── auth.ex                        # Authentication logic
│   ├── response.ex                    # Response parsing
│   └── error.ex                       # Error struct
test/
├── routeros_api_test.exs
├── routeros_api/
│   ├── connection_test.exs
│   ├── protocol_test.exs
│   ├── auth_test.exs
│   └── response_test.exs
└── support/
    └── mock_server.ex                 # Mock MikroTik server for testing
```

---

## Key Implementation Details

### 1. Protocol Module (`RouterosApi.Protocol`)

**Responsibilities:**
- Encode/decode length prefixes
- Read/write words
- Read/write sentences
- Read blocks

**Key Functions:**
```elixir
@spec encode_length(non_neg_integer()) :: binary()
@spec decode_length(binary()) :: {non_neg_integer(), binary()}
@spec write_word(port(), String.t()) :: :ok | {:error, term()}
@spec read_word(port()) :: {:ok, String.t()} | {:error, term()}
@spec write_sentence(port(), [String.t()]) :: :ok | {:error, term()}
@spec read_sentence(port()) :: {:ok, {atom(), [String.t()]}} | {:error, term()}
@spec read_block(port()) :: {:ok, [[String.t()]]} | {:error, term()}
```

**Length Encoding Rules:**
- `< 0x80` (128): 1 byte
- `< 0x4000` (16384): 2 bytes, first byte OR with 0x80
- `< 0x200000` (2097152): 3 bytes, first byte OR with 0xC0
- `< 0x10000000` (268435456): 4 bytes, first byte OR with 0xE0

---

### 2. Auth Module (`RouterosApi.Auth`)

**Responsibilities:**
- MD5 hash calculation
- Login sequence

**Key Functions:**
```elixir
@spec login(port(), String.t(), String.t()) :: :ok | {:error, term()}
```

**Login Flow:**
1. Send `/login` command
2. Receive salt in response (`=ret=<salt>`)
3. Calculate MD5: `md5(0x00 + password + hex_to_binary(salt))`
4. Send `/login` with `=name=<username>` and `=response=00<hash>`
5. Expect `!done` response

---

### 3. Connection Module (`RouterosApi.Connection`)

**GenServer State:**
```elixir
defmodule RouterosApi.Connection do
  defstruct [
    :socket,        # :gen_tcp or :ssl socket
    :host,
    :port,
    :username,
    :password,
    :ssl,           # boolean
    :ssl_opts,      # keyword list
    :timeout
  ]
end
```

**Key Callbacks:**
```elixir
def init(config) do
  # Connect and authenticate in init
  # Return {:ok, state} or {:stop, reason}
end

def handle_call({:command, words}, _from, state) do
  # Execute command synchronously
  # Return {:reply, {:ok, data} | {:error, reason}, state}
end

def terminate(_reason, state) do
  # Close socket
end
```

**Connection Logic:**
```elixir
defp connect(config) do
  case config.ssl do
    true -> ssl_connect(config)
    false -> tcp_connect(config)
  end
end

defp tcp_connect(config) do
  :gen_tcp.connect(
    String.to_charlist(config.host),
    config.port,
    [:binary, active: false],
    config.timeout
  )
end

defp ssl_connect(config) do
  :ssl.connect(
    String.to_charlist(config.host),
    config.port,
    [:binary, active: false] ++ config.ssl_opts,
    config.timeout
  )
end
```

---

### 4. Response Module (`RouterosApi.Response`)

**Responsibilities:**
- Parse raw sentences into structured data
- Handle `!done`, `!trap`, `!fatal`
- Convert `"=key=value"` to maps

**Key Functions:**
```elixir
@spec parse([[String.t()]]) :: {:ok, [map()]} | {:error, RouterosApi.Error.t()}
```

**Parsing Logic:**
```elixir
def parse(sentences) do
  sentences
  |> Enum.map(&parse_sentence/1)
  |> handle_status()
end

defp parse_sentence(words) do
  words
  |> Enum.reject(&is_status_word?/1)
  |> Enum.map(&parse_attribute/1)
  |> Enum.into(%{})
end

defp parse_attribute("=" <> rest) do
  case String.split(rest, "=", parts: 2) do
    [key, value] -> {key, coerce_value(value)}
    [key] -> {key, ""}
  end
end

defp coerce_value("true"), do: true
defp coerce_value("false"), do: false
defp coerce_value("yes"), do: true
defp coerce_value("no"), do: false
defp coerce_value(value), do: value
```

---

### 5. Public API Module (`RouterosApi`)

**Key Functions:**
```elixir
@spec connect(map()) :: {:ok, pid()} | {:error, term()}
@spec connect_plain(map()) :: {:ok, pid()} | {:error, term()}
@spec connect_tls(map()) :: {:ok, pid()} | {:error, term()}
@spec disconnect(pid()) :: :ok
@spec command(pid(), [String.t()]) :: {:ok, [map()]} | {:error, term()}
@spec command!(pid(), [String.t()]) :: [map()]
```

**Usage:**
```elixir
# Auto-detect based on port
{:ok, conn} = RouterosApi.connect(%{
  host: "192.168.88.1",
  port: 8728,
  username: "admin",
  password: "password"
})

# Execute command
{:ok, interfaces} = RouterosApi.command(conn, ["/interface/print"])

# Clean up
RouterosApi.disconnect(conn)
```


