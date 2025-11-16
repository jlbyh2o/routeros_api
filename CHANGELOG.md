# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-01-16

### Added
- **Connection Pooling** with NimblePool
  - Configurable pool size
  - Automatic health checks
  - Connection recovery
  - Supervision support

- **Telemetry Integration**
  - Connection events (start, stop, exception)
  - Command events (start, stop, exception)
  - Pool events (checkout, checkin)
  - Rich metadata for monitoring

- **Helper Functions** (`RouterosApi.Helpers`)
  - `list_interfaces/1` - List all interfaces
  - `get_interface/2` - Get specific interface
  - `list_ip_addresses/1` - List IP addresses
  - `add_ip_address/3` - Add IP address
  - `remove_ip_address/2` - Remove IP address
  - `get_system_resource/1` - Get system information
  - `get_identity/1` - Get router identity
  - `set_identity/2` - Set router identity
  - `list_firewall_rules/1` - List firewall rules
  - `list_dhcp_leases/1` - List DHCP leases
  - `reboot/1` - Reboot router

- **RouterOS 7.x Support**
  - Plain text authentication for RouterOS 6.43+
  - Automatic fallback to MD5 for older versions
  - Tested with RouterOS 7.12.1

- **Comprehensive Testing**
  - 109 tests (all passing)
  - Integration tests with real router
  - SSL/TLS integration tests
  - Pool tests
  - Telemetry tests
  - Helper function tests

- **SSL/TLS Support**
  - Full TLS/SSL connection support
  - Self-signed certificate support
  - Tested with RouterOS 7.12.1 on port 8729
  - Connection pooling works with TLS
  - All helpers work over TLS

### Changed
- Enhanced error handling and reporting
- Improved documentation with more examples
- Updated README with pooling and telemetry examples
- More conservative versioning (0.2.0 instead of 1.0.0)

### Fixed
- Protocol length decoding for all byte ranges
- Reply sentence (!re) handling
- Authentication compatibility with RouterOS 7.x
- SSL socket handling in Protocol module (send/recv)

## [0.1.0] - 2025-01-15

### Added
- Initial release (MVP)
- Binary protocol implementation for MikroTik RouterOS API
- Support for plain TCP connections (port 8728)
- Support for TLS connections (port 8729)
- MD5 challenge-response authentication
- Response parsing to Elixir maps
- Error handling with custom error struct
- Command execution with query filters
- Boolean type coercion
- Comprehensive documentation

[0.2.0]: https://github.com/jlbyh2o/routeros_api/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/jlbyh2o/routeros_api/releases/tag/v0.1.0

