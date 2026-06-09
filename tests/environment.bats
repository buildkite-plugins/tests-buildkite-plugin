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

@test "does not clobber a manually-set BUILDKITE_TEST_ENGINE_UPLOAD_RESULTS" {
  export BUILDKITE_TEST_ENGINE_UPLOAD_RESULTS="false"
  export BUILDKITE_ENV_FILE=$(mktemp)

  run $PWD/hooks/environment

  run cat ${BUILDKITE_ENV_FILE}
  refute_output --partial "BUILDKITE_TEST_ENGINE_UPLOAD_RESULTS=true"
}

@test "passes a tag string directly to bktec" {
  export BUILDKITE_PLUGIN_TESTS_TAGS="language.version=3.3"
  export BUILDKITE_ENV_FILE=$(mktemp)

  run $PWD/hooks/environment

  run cat ${BUILDKITE_ENV_FILE}
  assert_line "BUILDKITE_TEST_ENGINE_TAGS=language.version=3.3"
}

@test "passes a single tag to bktec" {
  export BUILDKITE_PLUGIN_TESTS_TAGS_0="language.version=3.3"
  export BUILDKITE_ENV_FILE=$(mktemp)

  run $PWD/hooks/environment

  run cat ${BUILDKITE_ENV_FILE}
  assert_line "BUILDKITE_TEST_ENGINE_TAGS=language.version=3.3"
}

@test "passes multiple tags to bktec as comma-separated values" {
  export BUILDKITE_PLUGIN_TESTS_TAGS_0="language.version=3.3"
  export BUILDKITE_PLUGIN_TESTS_TAGS_1="os=linux"
  export BUILDKITE_ENV_FILE=$(mktemp)

  run $PWD/hooks/environment

  run cat ${BUILDKITE_ENV_FILE}
  assert_line "BUILDKITE_TEST_ENGINE_TAGS=language.version=3.3,os=linux"
}

@test "does not set tags env var when no tags provided" {
  export BUILDKITE_ENV_FILE=$(mktemp)

  run $PWD/hooks/environment

  run cat ${BUILDKITE_ENV_FILE}
  refute_line --partial "BUILDKITE_TEST_ENGINE_TAGS"
}
