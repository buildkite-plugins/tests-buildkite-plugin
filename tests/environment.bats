#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"
}

@test "adds variables to the environment file" {
  export BUILDKITE_PLUGIN_TESTS_TEST_RUNNER="choochoo"
  export BUILDKITE_ENV_FILE=$(mktemp)

  run $PWD/hooks/environment

  run cat ${BUILDKITE_ENV_FILE}
  assert_line "BUILDKITE_TEST_ENGINE_TEST_RUNNER=choochoo"
}

@test "enables result upload by default" {
  export BUILDKITE_ENV_FILE=$(mktemp)

  run $PWD/hooks/environment

  run cat ${BUILDKITE_ENV_FILE}
  assert_output "BUILDKITE_TEST_ENGINE_UPLOAD_RESULTS=true"
}

@test "respects upload-results when set to false" {
  export BUILDKITE_PLUGIN_TESTS_UPLOAD_RESULTS="false"
  export BUILDKITE_ENV_FILE=$(mktemp)

  run $PWD/hooks/environment

  run cat ${BUILDKITE_ENV_FILE}
  assert_output "BUILDKITE_TEST_ENGINE_UPLOAD_RESULTS=false"
}
