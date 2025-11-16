# RouterOS API - Development Checklist

## Phase 1: MVP (v0.1.0)

### 1.1 Project Setup ✅
- [x] Run `mix new routeros_api --sup`
- [x] Configure mix.exs (metadata, version 0.1.0-dev)
- [x] Add MIT LICENSE file
- [x] Create initial README.md
- [x] Add .gitignore
- [x] Initialize git repository
- [x] Add CHANGELOG.md
- [x] Verify compilation works

### 1.2 Protocol Implementation ✅
- [x] Create `lib/routeros_api/protocol.ex`
- [x] Implement `encode_length/1`
- [x] Implement `decode_length/1`
- [x] Implement `write_word/2`
- [x] Implement `read_word/1`
- [x] Implement `write_sentence/2`
- [x] Implement `read_sentence/1`
- [x] Implement `read_block/1`
- [x] Add typespecs
- [x] Write unit tests for protocol
- [x] Import Bitwise for bitwise operations
- [x] Handle both :gen_tcp and :ssl sockets

### 1.3 Authentication ✅
- [x] Create `lib/routeros_api/auth.ex`
- [x] Implement MD5 hash calculation
- [x] Implement salt extraction
- [x] Implement login sequence
- [x] Add typespecs
- [x] Write unit tests for auth
- [x] Hex to binary conversion
- [x] Binary to hex conversion
- [x] Handle empty salt (newer RouterOS)

### 1.4 Connection Management ✅
- [x] Create `lib/routeros_api/connection.ex`
- [x] Create `lib/routeros_api/error.ex`
- [x] Define connection state struct
- [x] Implement `init/1` (connect + authenticate)
- [x] Implement TCP connection
- [x] Implement TLS connection
- [x] Auto-detect TLS from port
- [x] Implement `handle_call({:command, words}, ...)`
- [x] Implement `terminate/2`
- [x] Add error handling
- [x] Add typespecs
- [ ] Write integration tests (deferred - need mock server)

### 1.5 Response Parsing ✅
- [x] Create `lib/routeros_api/response.ex`
- [x] Implement sentence parsing
- [x] Implement attribute parsing (`=key=value`)
- [x] Implement status handling (!done, !trap, !fatal)
- [x] Implement type coercion (boolean, etc.)
- [x] Add typespecs
- [x] Write unit tests
- [x] Integrate with Connection module
- [x] Handle mixed status/data sentences

### 1.6 Error Handling ✅
- [x] Create `lib/routeros_api/error.ex`
- [x] Define error struct
- [x] Add error types (:trap, :fatal, :timeout, :closed, :auth_failed, :connection_failed)
- [x] Implement error formatting
- [x] Add typespecs
- [x] Implement Exception behaviour

### 1.7 Public API ✅
- [x] Create `lib/routeros_api.ex`
- [x] Implement `connect/1`
- [x] Implement `connect_plain/1`
- [x] Implement `connect_tls/1`
- [x] Implement `disconnect/1`
- [x] Implement `command/2`
- [x] Implement `command!/2`
- [x] Add @moduledoc and @doc
- [x] Add typespecs
- [x] Write API tests
- [x] Comprehensive documentation with examples

### 1.8 Testing ✅
- [x] Test protocol encoding/decoding
- [x] Test authentication flow (both MD5 and plain text)
- [x] Test TCP connections
- [x] Test command execution
- [x] Test error scenarios
- [x] Test response parsing
- [x] Integration tests with real router (RouterOS 7.12.1)
- [x] 81 tests passing (16 doctests + 65 unit/integration)
- [ ] TLS connections (deferred - need TLS-enabled router)

### 1.9 Documentation ✅
- [x] Add @moduledoc to all modules
- [x] Add @doc to all public functions
- [x] Create README with:
  - [x] Installation instructions
  - [x] Quick start example
  - [x] Basic usage
  - [x] TLS configuration
  - [x] Error handling
- [x] Add examples in module docs
- [x] Generate and review ExDocs locally

### 1.10 Quality Checks ✅
- [x] Run `mix format`
- [x] Run `mix test` (all passing - 81 tests)
- [x] Run `mix compile --warnings-as-errors`
- [x] Fix any compiler warnings
- [x] Review all code
- [x] Test with real RouterOS 7.12.1 device
- [x] SSL/TLS integration tests (9 tests passing)
- [x] Test with self-signed certificate

---

## Phase 2: Production Ready (v1.0.0)

### 2.1 Connection Pooling ✅
- [x] Add `nimble_pool` dependency
- [x] Create `lib/routeros_api/pool.ex`
- [x] Implement pool worker
- [x] Implement checkout/checkin
- [x] Add pool supervision (child_spec/1)
- [x] Update `RouterosApi.command/2` to support pools
- [x] Write pool tests (5 tests passing)
- [x] Document pool usage
- [x] Test concurrent requests
- [x] Test error handling in pool

### 2.2 Telemetry ✅
- [x] Add `telemetry` dependency
- [x] Add connection events (start, stop, exception)
- [x] Add command events (start, stop, exception)
- [x] Add pool events (checkout, checkin)
- [x] Add metadata to events (host, port, command, duration, etc.)
- [x] Write telemetry tests (4 tests passing)
- [x] Document telemetry usage in README
- [x] Example telemetry handler in README

### 2.3 Helper Functions ✅
- [x] Implement `list_interfaces/1`
- [x] Implement `get_interface/2`
- [x] Implement `list_ip_addresses/1`
- [x] Implement `add_ip_address/3`
- [x] Implement `remove_ip_address/2`
- [x] Implement `get_system_resource/1`
- [x] Implement `get_identity/1`
- [x] Implement `set_identity/2`
- [x] Implement `list_firewall_rules/1`
- [x] Implement `list_dhcp_leases/1`
- [x] Implement `reboot/1`
- [x] Add tests for helpers (10 tests passing)
- [x] Document helpers in README
- [x] Test helpers with pools

### 2.4 CI/CD ⏳
- [ ] Create `.github/workflows/ci.yml`
- [ ] Add test matrix (OTP 24, 25, 26)
- [ ] Add Elixir versions (1.14, 1.15, 1.16)
- [ ] Add Dialyzer checks
- [ ] Add Credo checks
- [ ] Add format checks
- [ ] Verify CI passes

### 2.5 Documentation ⏳
- [ ] Expand README with Phoenix examples
- [ ] Add LiveView example
- [ ] Add Context example
- [ ] Add pooling guide
- [ ] Create CHANGELOG.md
- [ ] Add production deployment guide
- [ ] Generate ExDocs

### 2.6 Quality Checks ⏳
- [ ] Run `mix credo --strict`
- [ ] Run `mix dialyzer`
- [ ] Fix all issues
- [ ] Review all documentation
- [ ] Update version to 1.0.0

---

## Phase 3: Publication

### 3.1 Hex Package ⏳
- [ ] Review mix.exs metadata
- [ ] Add package links
- [ ] Add keywords
- [ ] Run `mix hex.build`
- [ ] Review package contents
- [ ] Run `mix hex.publish`
- [ ] Verify on hex.pm
- [ ] Verify docs on hexdocs.pm

### 3.2 Announcement ⏳
- [ ] Create GitHub release
- [ ] Tag version
- [ ] Write release notes
- [ ] Share on Elixir Forum (optional)
- [ ] Share on social media (optional)

---

## ✅ Completion Criteria

- [ ] All tests passing
- [ ] No compiler warnings
- [ ] Dialyzer clean
- [ ] Credo clean
- [ ] Documentation complete
- [ ] Published to hex.pm
- [ ] Works in Phoenix project

