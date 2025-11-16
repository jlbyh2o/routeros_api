# RouterOS API - Elixir Hex Package Conversion Plan

## Project Overview
Convert the old Erlang "erotik" library into a modern Elixir hex package called **routeros_api** for Phoenix/Elixir projects.

**Key Decisions:**
- ✅ New package name: `routeros_api` (available on hex.pm)
- ℹ️  Note: `mikrotik_api` exists but uses REST API; we use binary API protocol
- ✅ Support both standard (8728) and secure (8729) API ports
- ✅ Remove SSH functionality (API protocol only)
- ✅ No backward compatibility required
- ✅ Fresh Elixir implementation (original has no license)
- ✅ Target: Production-ready hex package

---

## Phase 1: MVP - Core Functionality ⏳
**Goal:** Working library with direct connections, sync commands, parsed responses

**Status:** NOT STARTED

### 1.1 Project Setup & Structure
- [ ] Create new Mix project structure
  - [ ] Run `mix new routeros_api --sup`
  - [ ] Set up proper directory structure
- [ ] Configure `mix.exs`
  - [ ] Add package metadata (description, links, keywords)
  - [ ] Set version to 0.1.0-dev (pre-release)
  - [ ] Configure for hex package
  - [ ] Add dependencies: none for Phase 1
- [ ] Add LICENSE file (MIT recommended)
- [ ] Create initial README.md with project goals
- [ ] Add .gitignore for Elixir projects

**Estimated Time:** 1 hour

---

### 1.2 Protocol Implementation
**Understanding MikroTik API Protocol:**
The protocol uses a binary format over TCP (port 8728):
- Length-encoded words
- Sentence-based communication
- MD5 challenge-response authentication
- Block-based responses

**Tasks:**
- [ ] Implement `RouterosApi.Protocol` module
  - [ ] Length encoding/decoding functions
  - [ ] Word reading/writing
  - [ ] Sentence reading/writing
  - [ ] Block reading
- [ ] Implement `RouterosApi.Auth` module
  - [ ] MD5 hash calculation
  - [ ] Login sequence handling
  - [ ] Salt extraction
- [ ] Add proper typespecs for all functions
- [ ] Write unit tests for protocol functions

**Reference Files (Erlang):**
- `src/core/me_core.erl` - encoding/decoding
- `src/io/me_api.erl` - sentence/word I/O
- `src/core/me_logic.erl` - login logic

**Estimated Time:** 4-5 hours

---

### 1.3 Connection Management (Direct Connections Only)
**Tasks:**
- [ ] Implement `RouterosApi.Connection` GenServer
  - [ ] TCP connection handling (port 8728)
  - [ ] TLS/SSL connection handling (port 8729)
  - [ ] Automatic authentication on connect
  - [ ] Command execution (synchronous only)
  - [ ] Error handling
  - [ ] Graceful shutdown
- [ ] Add connection configuration
  - [ ] Host (required)
  - [ ] Port (optional, defaults: 8728 plain, 8729 TLS)
  - [ ] Username and password (required)
  - [ ] SSL/TLS options (verify peer, certificates)
  - [ ] Timeout settings
- [ ] Write integration tests (mock TCP server)
  - [ ] Test both plain and TLS connections

**Reference Files (Erlang):**
- `src/core/me_connector.erl` - connection GenServer

**TLS Implementation Notes:**
- Use `:ssl.connect/3` for TLS connections
- Support certificate verification options
- Allow self-signed certificates for lab environments
- Default to secure settings (verify peer)
- Auto-detect TLS vs plain based on port (8729 = TLS, 8728 = plain)
- Allow explicit override via `connect_tls/1` or `connect_plain/1`
- Support custom ports (user-configurable)

**Estimated Time:** 4-5 hours

---

### 1.4 Public API & Response Parsing
**Tasks:**
- [ ] Implement `RouterosApi` main module
  - [ ] `connect/1` - connect with config map (auto-detect TLS from port)
  - [ ] `connect_plain/1` - explicit plain TCP connection
  - [ ] `connect_tls/1` - explicit TLS connection
  - [ ] `disconnect/1` - close connection
  - [ ] `command/2` - execute command, return `{:ok, data}` or `{:error, reason}`
  - [ ] `command!/2` - execute command, return data or raise
- [ ] Implement response parsing (`RouterosApi.Response`)
  - [ ] Parse `!done`, `!trap`, `!fatal` responses
  - [ ] Convert `"=key=value"` to `%{"key" => "value"}`
  - [ ] Handle multiple result rows
  - [ ] Type coercion for common fields (boolean, integer)
- [ ] Define error struct (`RouterosApi.Error`)
  - [ ] Type: `:trap`, `:fatal`, `:timeout`, `:closed`
  - [ ] Message and metadata

**Estimated Time:** 3-4 hours

---

### 1.5 Testing & Documentation
**Tasks:**
- [ ] Unit tests for all modules
  - [ ] Protocol encoding/decoding
  - [ ] Authentication logic
  - [ ] Response parsing
- [ ] Integration tests
  - [ ] Mock MikroTik server
  - [ ] Connection lifecycle
  - [ ] Command execution
  - [ ] Error scenarios
- [ ] Add @moduledoc and @doc to all public functions
- [ ] Create basic README.md
  - [ ] Installation instructions
  - [ ] Quick start guide
  - [ ] Basic examples

**Estimated Time:** 4-5 hours

---

**Phase 1 Total: 16-20 hours**
**Deliverable:** v0.1.0 - Working library with direct connections

---

## Phase 2: Production Ready ⏳
**Goal:** Connection pooling, telemetry, comprehensive docs

**Status:** NOT STARTED

### 2.1 Connection Pooling
**Tasks:**
- [ ] Add NimblePool dependency
- [ ] Implement `RouterosApi.Pool` module
  - [ ] Pool worker implementation
  - [ ] Checkout/checkin logic
  - [ ] Health checks
  - [ ] Configuration (pool_size, etc.)
- [ ] Update `RouterosApi` to support pooled connections
  - [ ] `command/2` works with both pid and pool name
- [ ] Add pool supervision
- [ ] Write pool-specific tests

**Estimated Time:** 3-4 hours

---

### 2.2 Telemetry Integration
**Tasks:**
- [ ] Add Telemetry dependency
- [ ] Implement telemetry events
  - [ ] `[:routeros_api, :connection, :start]`
  - [ ] `[:routeros_api, :connection, :stop]`
  - [ ] `[:routeros_api, :connection, :exception]`
  - [ ] `[:routeros_api, :command, :start]`
  - [ ] `[:routeros_api, :command, :stop]`
  - [ ] `[:routeros_api, :command, :exception]`
- [ ] Add metadata to events
- [ ] Document telemetry usage

**Estimated Time:** 2-3 hours

---

### 2.3 Helper Functions & Conveniences
**Tasks:**
- [ ] Add common helper functions
  - [ ] `list_interfaces/1` - Get all interfaces
  - [ ] `get_interface/2` - Get specific interface
  - [ ] `list_ip_addresses/1` - Get IP addresses
  - [ ] `list_routes/1` - Get routing table
  - [ ] `get_system_resource/1` - Get system info
- [ ] Add query helpers (optional)
  - [ ] Query builder for filters
  - [ ] Attribute helpers

**Estimated Time:** 2-3 hours

---

### 2.4 Advanced Testing & CI/CD
**Tasks:**
- [ ] Property-based tests (optional)
  - [ ] Protocol encoding round-trips
- [ ] Set up CI/CD
  - [ ] GitHub Actions workflow
  - [ ] Test matrix (OTP 24, 25, 26)
  - [ ] Elixir versions (1.14, 1.15, 1.16)
  - [ ] Dialyzer checks
  - [ ] Credo checks

**Estimated Time:** 2-3 hours

---

### 2.5 Comprehensive Documentation
**Tasks:**
- [ ] Expand README.md
  - [ ] Phoenix integration guide
  - [ ] LiveView examples
  - [ ] Context examples
  - [ ] Pooling setup guide
- [ ] Add usage examples
  - [ ] Basic connection (plain TCP)
  - [ ] Secure connection (TLS)
  - [ ] Certificate verification
  - [ ] Common commands
  - [ ] Error handling
  - [ ] Pooling setup
- [ ] Generate ExDoc documentation
- [ ] Create CHANGELOG.md
- [ ] Add guides
  - [ ] Getting Started
  - [ ] Phoenix Integration
  - [ ] Production Deployment

**Estimated Time:** 3-4 hours

---

**Phase 2 Total: 12-17 hours**
**Deliverable:** v1.0.0 - Production-ready with pooling and telemetry

---

## Phase 3: Hex Package Publication ⏳
**Goal:** Publish to hex.pm

**Status:** NOT STARTED

### Tasks:
- [ ] Final mix.exs review
  - [ ] Verify all metadata
  - [ ] Add package links (GitHub, docs)
  - [ ] Set proper version (1.0.0)
  - [ ] Add keywords and description
- [ ] Run quality checks
  - [ ] `mix format --check-formatted`
  - [ ] `mix credo --strict`
  - [ ] `mix dialyzer`
  - [ ] No compiler warnings
  - [ ] All tests passing
- [ ] Test hex package build
  - [ ] `mix hex.build`
  - [ ] Verify package contents
- [ ] Publish to hex.pm
  - [ ] `mix hex.publish`
- [ ] Publish documentation
  - [ ] Verify on hexdocs.pm

**Estimated Time:** 1-2 hours

---

## Total Estimated Time

- **Phase 1 (MVP):** 16-20 hours
- **Phase 2 (Production):** 12-17 hours
- **Phase 3 (Publication):** 1-2 hours
- **Total:** 29-39 hours

---

## Success Criteria

### Phase 1 (v0.1.0):
- ✅ All tests passing
- ✅ Successfully connects to MikroTik router (plain and TLS)
- ✅ Can execute commands and parse responses to maps
- ✅ Error handling works correctly
- ✅ Basic documentation complete
- ✅ No compiler warnings

### Phase 2 (v1.0.0):
- ✅ Connection pooling works
- ✅ Telemetry events firing correctly
- ✅ Helper functions implemented
- ✅ Comprehensive documentation
- ✅ Dialyzer passes with no errors
- ✅ CI/CD pipeline working
- ✅ Works seamlessly in Phoenix projects

### Phase 3:
- ✅ Published to hex.pm
- ✅ Documentation on hexdocs.pm

---

## Notes

### MikroTik API Protocol Reference
- Port 8728: Plain TCP (default)
- Port 8729: TLS/SSL encrypted (default)
- Custom ports: Fully supported (user-configurable)
- Protocol: Binary over TCP
- Authentication: MD5 challenge-response
- Commands: Sentence-based (list of words)
- TLS: Standard Erlang/OTP SSL support

**Port Configuration:**
- Ports are configurable to support custom MikroTik configurations
- Auto-detection: port 8729 → TLS, others → plain TCP
- Explicit functions available: `connect_plain/1`, `connect_tls/1`
- Useful for port forwarding, NAT, or changed defaults

### Removed from Original
- SSH connection support
- Example application code
- Rebar build system
- Hardcoded router configurations

### Added Features
- TLS/SSL support (port 8729)
- Certificate verification options
- Modern Elixir idioms
- Connection pooling
- Telemetry integration

---

## TLS/SSL Configuration Examples

### Basic TLS Connection (port 8729)
```elixir
# Auto-detect TLS from port
{:ok, conn} = RouterosApi.connect(%{
  host: "192.168.88.1",
  port: 8729,  # TLS port
  username: "admin",
  password: "password"
})
```

### TLS with Certificate Verification
```elixir
# Verify peer with CA certificate
{:ok, conn} = RouterosApi.connect_tls(%{
  host: "router.example.com",
  port: 8729,
  username: "admin",
  password: "password",
  ssl_opts: [
    verify: :verify_peer,
    cacertfile: "/path/to/ca.pem"
  ]
})
```

### TLS with Self-Signed Certificate (Lab/Testing)
```elixir
# Accept self-signed certificates (NOT for production)
{:ok, conn} = RouterosApi.connect_tls(%{
  host: "192.168.88.1",
  port: 8729,
  username: "admin",
  password: "password",
  ssl_opts: [
    verify: :verify_none
  ]
})
```

### Plain TCP Connection (port 8728)
```elixir
# Explicit plain connection (default port)
{:ok, conn} = RouterosApi.connect_plain(%{
  host: "192.168.88.1",
  username: "admin",
  password: "password"
})

# Or with explicit port
{:ok, conn} = RouterosApi.connect_plain(%{
  host: "192.168.88.1",
  port: 8728,
  username: "admin",
  password: "password"
})
```

### Custom Ports
```elixir
# Custom plain TCP port (e.g., port forwarding or changed default)
{:ok, conn} = RouterosApi.connect_plain(%{
  host: "router.example.com",
  port: 9999,  # Custom port
  username: "admin",
  password: "password"
})

# Custom TLS port
{:ok, conn} = RouterosApi.connect_tls(%{
  host: "router.example.com",
  port: 9998,  # Custom TLS port
  username: "admin",
  password: "password",
  ssl_opts: [verify: :verify_peer]
})

# Auto-detect based on custom port (will use plain TCP for non-8729)
{:ok, conn} = RouterosApi.connect(%{
  host: "router.example.com",
  port: 9999,  # Will use plain TCP
  username: "admin",
  password: "password"
})
```

