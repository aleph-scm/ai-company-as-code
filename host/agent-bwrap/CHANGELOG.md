# Changelog

All notable changes to this project are documented in this file.

## [0.1.0] - 2026-09-25

Initial public extraction. `bin/agent-bwrap` is a generalized, parameterized
version of a Bubblewrap wrapper originally built for one company's internal
coding-agent deployment: same confinement model (workspace read-write, an
allowlisted read-only system surface, optional extra read-write/read-only
binds), but with every hostname, path, and environment-variable name specific
to that deployment replaced by configuration (`AGENT_BWRAP_CMD`,
`AGENT_BWRAP_WORKSPACE`, `AGENT_BWRAP_RW`, `AGENT_BWRAP_RO`,
`AGENT_BWRAP_SYSTEM_RO`, `AGENT_BWRAP_CONFIG`).

### Added

- `bin/agent-bwrap`: the wrapper script.
- `apparmor/agent-bwrap.profile.example`: example AppArmor profile for hosts
  that restrict unprivileged user-namespace creation.
- `config/agent-bwrap.env.example`: documented example configuration.
- Test suite (`tests/`) covering: writes outside the sandbox mounts are
  silently discarded; reads outside the boundary fail as absent; bound
  credentials are read-only; network access is unconfined; missing required
  configuration refuses to start. Runs in GitHub Actions on `ubuntu-latest`.
- MIT license.
