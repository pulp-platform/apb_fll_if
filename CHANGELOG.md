# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-03-13

### Changed

- Bumped `apb` dependency to `0.2.4`
- Refactored `apb_to_fll` to be struct based instead of interface based.
- Cleaned up the `apb_to_fll` module.


### Added

- SystemVerilog FLL model for verification purposes.
- Tracked `Bender.lock`
- Verilator simulation setup, with CI.
- SystemRDL description of the FLL interface, together with an example SW driver.
- Added `pyproject.toml` with `peakrdl` dependency managed by `uv` for SystemRDL code generation.

### Removed

- `src_files.yml`, replaced by `Bender.yml`. (https://github.com/pulp-platform/apb_fll_if/pull/4)
- `apb_fll_if` version, which relied on arrays of interfaces that are known to be unsupported by the tools. (https://github.com/pulp-platform/apb_fll_if/pull/4)
