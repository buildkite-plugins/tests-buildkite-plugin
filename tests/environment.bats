#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"
}

@test "adds variables to the environment file" {
  export BUILDKITE_PLUGIN_TEST_ENGINE_TEST_RUNNER="choochoo"
  export BUILDKITE_ENV_FILE=$(mktemp)

  run $PWD/hooks/environment

  run cat ${BUILDKITE_ENV_FILE}
  assert_output "BUILDKITE_TEST_ENGINE_TEST_RUNNER=choochoo"
}
