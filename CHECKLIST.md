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

### 1.7 Public API ⏳
- [ ] Create `lib/routeros_api.ex`
- [ ] Implement `connect/1`
- [ ] Implement `connect_plain/1`
- [ ] Implement `connect_tls/1`
- [ ] Implement `disconnect/1`
- [ ] Implement `command/2`
- [ ] Implement `command!/2`
- [ ] Add @moduledoc and @doc
- [ ] Add typespecs
- [ ] Write integration tests

### 1.8 Testing ⏳
- [ ] Create mock MikroTik server in `test/support/`
- [ ] Test protocol encoding/decoding
- [ ] Test authentication flow
- [ ] Test TCP connections
- [ ] Test TLS connections
- [ ] Test command execution
- [ ] Test error scenarios
- [ ] Test response parsing
- [ ] Ensure 100% test coverage for critical paths

### 1.9 Documentation ⏳
- [ ] Add @moduledoc to all modules
- [ ] Add @doc to all public functions
- [ ] Create README with:
  - [ ] Installation instructions
  - [ ] Quick start example
  - [ ] Basic usage
  - [ ] TLS configuration
  - [ ] Error handling
- [ ] Add examples in module docs
- [ ] Generate and review ExDocs locally

### 1.10 Quality Checks ⏳
- [ ] Run `mix format`
- [ ] Run `mix test` (all passing)
- [ ] Run `mix compile --warnings-as-errors`
- [ ] Fix any compiler warnings
- [ ] Review all code

---

## Phase 2: Production Ready (v1.0.0)

### 2.1 Connection Pooling ⏳
- [ ] Add `nimble_pool` dependency
- [ ] Create `lib/routeros_api/pool.ex`
- [ ] Implement pool worker
- [ ] Implement checkout/checkin
- [ ] Add pool supervision
- [ ] Update `RouterosApi.command/2` to support pools
- [ ] Write pool tests
- [ ] Document pool usage

### 2.2 Telemetry ⏳
- [ ] Add `telemetry` dependency
- [ ] Add connection events
- [ ] Add command events
- [ ] Add pool events
- [ ] Add metadata to events
- [ ] Write telemetry tests
- [ ] Document telemetry usage

### 2.3 Helper Functions ⏳
- [ ] Implement `list_interfaces/1`
- [ ] Implement `get_interface/2`
- [ ] Implement `list_ip_addresses/1`
- [ ] Implement `list_routes/1`
- [ ] Implement `get_system_resource/1`
- [ ] Add tests for helpers
- [ ] Document helpers

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

