# Tests Buildkite Plugin [![Build status](https://badge.buildkite.com/74fa0467f2882c02503bf4fea1fec74d1ce5830e47307651bb.svg?branch=main)](https://buildkite.com/buildkite/plugins-tests)

The Buildkite plugin for automatically parallelising and running your test suites on Buildkite. It splits your tests across parallel jobs so they finish faster, and handles all the setup for you. The splitting and running is done by [bktec](https://github.com/buildkite/test-engine-client), the client this plugin installs and configures for you.

Behind the scenes, the plugin downloads bktec, requests an [OIDC](https://buildkite.com/docs/pipelines/security/oidc) token, ensures your [test suite](https://buildkite.com/docs/test-engine/test-suites) exists, and exports the environment variables bktec expects, so you do not have to install bktec, set up authentication, or create your test suite by hand. It works with every test runner that bktec supports, including RSpec, Jest, pytest, and Go test.

## Example

```yaml
steps:
  - label: "RSpec"
    command: bktec run
    plugins:
      - tests#v1.0.0:
          test-runner: rspec
          result-path: tmp/rspec-result.json
    parallelism: 2
```

Each step must invoke `bktec run` (or `bktec plan`) in its command — the plugin sets up the environment but does not run the test command for you. The plugin downloads bktec by default; set `install-client: false` if bktec is already installed on the agent.

If the `suite-slug` attribute is not set, the plugin uses the pipeline slug as the test suite slug. If the test suite does not exist yet, the plugin creates it from the pipeline on the first run.

## Examples by runner

### Jest

```yaml
steps:
  - label: "Jest"
    command: bktec run
    plugins:
      - tests#v1.0.0:
          test-runner: jest
          result-path: jest-results.json
    parallelism: 4
```

### pytest

```yaml
steps:
  - label: "Run tests"
    command: bktec run
    parallelism: 5
    plugins:
      - tests#v1.0.0:
          test-runner: pytest
```

### Go test

```yaml
steps:
  - label: "Go test"
    command: bktec run
    plugins:
      - tests#v1.0.0:
          test-runner: gotest
          result-path: gotest-results.xml
    parallelism: 4
```

### Dynamic parallelism

To let bktec choose the number of partitions for a target run time, run `bktec plan` in a planning step with the `--pipeline-upload` flag, pointing at a pipeline template you supply. `bktec plan` uploads a follow-up step that runs the test plan. `--pipeline-upload` is passed directly to `bktec` in `command:` because it is not exposed as a plugin option (see [Unsupported bktec flags](#unsupported-bktec-flags)).

```yaml
steps:
  - label: "Plan RSpec"
    key: rspec-plan
    command: bktec plan --pipeline-upload .buildkite/rspec-template.yml
    plugins:
      - tests#v1.0.0:
          test-runner: rspec
          result-path: tmp/rspec-result.json
          max-parallelism: 10
          target-time: 4m30s
```

The pipeline template at `.buildkite/rspec-template.yml` contains the run step:

```yaml
steps:
  - label: "RSpec"
    key: rspec-run
    depends_on: rspec-plan
    command: bktec run --plan-identifier ${BUILDKITE_TEST_ENGINE_PLAN_IDENTIFIER}
    parallelism: ${BUILDKITE_TEST_ENGINE_PARALLELISM}
    plugins:
      - tests#v1.0.0:
          test-runner: rspec
          result-path: tmp/rspec-result.json
```

### Docker

When the test command runs inside a Docker container, the plugin downloads bktec on the host (the default) and sets `BUILDKITE_TEST_ENGINE_CLIENT_PATH` that you can mount into the container. Set `propagate-environment: true` on the Docker plugin so the container picks up the `BUILDKITE_TEST_ENGINE_*` variables that are required to run `bktec`. Set `client-os` and `client-arch` when the host operating system or architecture differs from the container.

```yaml
steps:
  - label: "Jest"
    command: bktec run
    plugins:
      - tests#v1.0.0:
          test-runner: jest
          client-os: linux
          result-path: jest-results.json
      - docker#v5.13.0:
          image: node:24-slim
          expand-volume-vars: true
          volumes:
            - "$$BUILDKITE_TEST_ENGINE_CLIENT_PATH:/usr/local/bin/bktec"
          propagate-environment: true
```

## Configuration

### bktec options

These options map directly to bktec flags or environment variables. For the full reference, see the [Test Engine Client repository](https://github.com/buildkite/test-engine-client).

#### `test-runner` (required, string)

Any runner supported by bktec, for example `rspec`, `jest`, `pytest`, or `gotest`.

#### `test-cmd` (required for `custom` and `pytest-pants` runners, string)

Command to run tests.

#### `result-path` (string)

Path to the test runner's output file. Required for all runners except `cypress`, `pytest`, `pytest-pants`, and `custom`.

#### `suite-slug` (optional, string)

Test suite slug. Defaults to the pipeline slug.

#### `test-file-pattern` (required for `custom` runner, string)

Glob pattern for test files.

#### `test-file-exclude-pattern` (optional, string)

Exclude test files matching this pattern.

#### `tag-filters` (optional, string)

Filter tests by tag. Currently only supported by pytest.

#### `files` (optional, string)

Path to a file that lists test files to run, one per line.

#### `retry-count` (optional, integer)

Number of times to retry failing tests.

#### `retry-cmd` (optional, string)

Command to run when retrying failed tests. Defaults to `test-cmd`.

#### `disable-retry-for-muted-test` (optional, boolean)

Disable retry for muted tests.

#### `split-by-example` (optional, boolean)

Enable example-level splitting. Not supported by every runner.

#### `location-prefix` (optional, string)

Prefix to prepend to test file paths when requesting a test plan.

#### `max-parallelism` (optional, integer)

Maximum parallelism for dynamic test plans. Used with `bktec plan`.

#### `target-time` (optional, string)

Desired target time for the test suite, for example `4m30s`. Must be used with `max-parallelism`.

#### `plan-identifier` (optional, string)

Test plan identifier created by `bktec plan`. Set automatically in dynamic mode; can be set manually for static mode.

#### `fail-on-no-tests` (optional, boolean)

Exit with an error if no tests are assigned to this node.

#### `upload-results` (optional, boolean)

Upload test results to your test suite. Default: `true`. Set to `false` if you use the [test collectors](https://buildkite.com/docs/test-engine/test-collection/) for richer data collection, or if you want to handle the upload yourself.

Requires bktec 2.7.0 or later.

#### `tags` (optional, array of strings)

Tags to attach to the uploaded test results. Each tag is a `key=value` string.

```yaml
plugins:
  - tests#v1.0.0:
      test-runner: rspec
      tags:
        - "language.version=3.3"
        - "os=linux"
```

#### `debug-enabled` (optional, boolean)

Enable verbose output.

### Plugin options

These options control plugin behavior and are not passed to bktec.

#### `install-client` (optional, boolean)

Download the bktec binary, add it to the `PATH`, and set `BUILDKITE_TEST_ENGINE_CLIENT_PATH`. Default: `true`. Set to `false` if bktec is already installed on the agent.

#### `client-os` (optional, string)

Target OS for the downloaded binary, for example `linux` or `darwin`. Defaults to the host OS. Useful when the host and a Docker container run different operating systems.

#### `client-arch` (optional, string)

Target architecture for the downloaded binary, for example `amd64` or `arm64`. Defaults to the host architecture.

#### `client-version` (optional, string)

bktec version to download, for example `2.4.0`. Defaults to the latest release.

#### `oidc-lifetime` (optional, integer)

Lifetime in seconds for the OIDC token. Default: `300`.

## Unsupported bktec flags

A small number of bktec flags cannot be set through environment variables, so the plugin intentionally does not expose them as options. To use any of these, pass them directly to `bktec` in your step's `command:`.

| Flag                | Command                    | Notes                                               |
| ------------------- | -------------------------- | --------------------------------------------------- |
| `--selection-param` | `run`, `plan`              | Preview selection                                   |
| `--metadata`        | `run`, `plan`              | Preview selection                                   |
| `--json`            | `plan`                     | Print the plan as JSON to stdout                    |
| `--pipeline-upload` | `plan`                     | Upload a follow-up pipeline step that runs the plan |
| `--output`          | `backfill-commit-metadata` | Write tarball locally                               |
| `--upload`          | `backfill-commit-metadata` | Upload an existing tarball                          |
| `--version`         | Global                     | No environment variable needed                      |

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/buildkite-plugins/tests-buildkite-plugin.

## License

MIT (see [LICENSE.txt](LICENSE.txt)).
