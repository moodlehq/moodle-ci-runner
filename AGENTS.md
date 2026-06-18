# AGENTS.md — Moodle CI Runner

## Architecture Overview

This is a **Bash-based CI orchestrator** that runs PHPUnit and Behat tests for Moodle inside Docker containers. It uses a `jobs → modules → stages` model:

- **Jobs** (`runner/main/jobtypes/`): Top-level test types (`phpunit`, `behat`, `postjobs`, `performance`). Each declares which modules it needs and in what order, then implements `_run`.
- **Modules** (`runner/main/modules/`): Reusable units (e.g., `docker`, `docker-php`, `docker-database`, `env`, `git`, `browser`). Like mini-jobs but without `_run` or `_modules`.
- **Stages**: Executed in fixed order by `runner/main/lib.sh`: `env+check → config → setup → run → teardown` (teardown runs in reverse module order).

**Canonical code lives in `runner/main/`.** All other numbered directories (`runner/31/`, `runner/400/`, etc.) are exact copies kept for historical/version-mapping purposes — only ever edit `runner/main/`.

## Function Naming Convention

Every job/module uses its name as a prefix for all stage functions. A job named `phpunit` implements:

| Function | Required | Purpose |
|---|---|---|
| `phpunit_env` | ✅ | Declare owned env variables (must include `EXITCODE`) |
| `phpunit_check` | ✅ | Assert dependencies via `verify_modules`, `verify_env`, `verify_utilities` |
| `phpunit_modules` | ✅ (jobs only) | Return ordered list of required modules |
| `phpunit_run` | ✅ (jobs only) | Main execution; always sets `EXITCODE` |
| `phpunit_config` | If has env vars | Set defaults; no instantiation here |
| `phpunit_setup` | Optional | Instantiate artefacts; no config logic here |
| `phpunit_teardown` | Optional | Cleanup; runs after `_run` via trap |
| `phpunit_to_env_file` | Optional | Variables to write to Docker env file |
| `phpunit_to_summary` | Optional | Variables to print in run summary |

Modules follow the same API **except** they have no `_run` or `_modules` functions.

Module names with hyphens (e.g., `docker-php`) use the hyphen in function names too: `docker-php_env()`.

## Adding a New Job or Module

1. Create `runner/main/jobtypes/<name>/<name>.sh` (job) or `runner/main/modules/<name>/<name>.sh` (module).
2. Implement all required functions with the name prefix.
3. For a new job: add it to the `_modules()` list of any job that needs it; reference `test/fixtures/jobtypes/dummy/dummy.sh` as a minimal job template.
4. Add a corresponding `test/<name>_test.bats` file.

## Key Runtime Variables

| Variable | Set by | Purpose |
|---|---|---|
| `UUID` | `run.sh` | 16-char hex suffix on all Docker container names for isolation |
| `SHAREDDIR` | `run.sh` | `$WORKSPACE/$BUILD_ID` — mounted as `/shared` in containers |
| `ENVIROPATH` | `env` module | Env file passed to containers via `--env-file` |
| `WEBSERVER` | `docker-php` module | Container name for the PHP/Apache container |
| `EXITCODE` | Each job | Accumulated exit code; runner exits with this value |
| `MOODLE_BRANCH` | `moodle-branch` module | Parsed from `version.php` in `CODEDIR` |

Variables passed to containers are declared in the job's `_to_env_file()` function; the `env` module writes them to `ENVIROPATH` during setup.

## Running Tests Locally

Tests use [Bats](https://github.com/bats-core/bats-core) and require a separate Moodle checkout:

```bash
export MOODLE_CI_RUNNER_GITDIR=/path/to/moodle.git  # must have full history (fetch-depth: 0)
bats test/runner_test.bats        # runner/orchestration tests
bats test/phpunit_test.bats       # PHPUnit job integration tests
bats test/behat_test.bats         # Behat job integration tests
```

Tests perform **destructive git checkouts** on `MOODLE_CI_RUNNER_GITDIR` — always use a dedicated clone. The `_common_teardown` helper resets it to `main` after each test.

The `dummy` job type in `test/fixtures/jobtypes/dummy/` is installed/removed per test suite in `runner_test.bats` — it's the minimal reference for a working job.

## Running Moodle Tests

```bash
export CODEDIR=/path/to/workspace/moodle
export JOBTYPE=phpunit   # or behat
export DBTYPE=pgsql
export PHP_VERSION=8.3
./runner/main/run.sh
```

Deprecated variable names (`TESTTORUN`, `TAGS`, `TESTSUITE`, `DBSLAVES`, etc.) still work but emit warnings. Use the current names listed in `README.md`.

## Module Dependency Rules

- A module can only use `verify_modules` to assert earlier modules are loaded — it cannot request new modules.
- Module ordering in a job's `_modules()` list is a hard dependency contract: `docker` must precede `docker-php`; `env` must precede anything using `ENVIROPATH`; `docker-summary` must be last among docker modules.
- `_config` functions must not instantiate resources; `_setup` functions must not set config defaults. This separation is enforced by code review convention.

## Docker Container Lifecycle

All containers share a Docker network (`NETWORK`, default `moodle`) and are named `<role><UUID>` (e.g., `webserver<UUID>`, `pgsql<UUID>`). The `docker` module's `_teardown` stops and removes all containers matching `UUID`. The `docker-php` module mounts `SHAREDDIR` as `/shared` and `COMPOSERCACHE` as `/var/www/.composer`.

