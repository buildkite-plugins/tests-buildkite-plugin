#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"

  # Uncomment to debug the relevant stubbed commands
  # export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
  # export CURL_STUB_DEBUG=/dev/tty
  # export MKTEMP_STUB_DEBUG=/dev/tty
}

@test "sets env vars" {
  export BUILDKITE_ENV_FILE=$(mktemp)
  export BUILDKITE_ORGANIZATION_SLUG="myorg" 
  export BUILDKITE_PIPELINE_SLUG="mypipeline" 

  audience="https://buildkite.com/organizations/myorg/analytics/suites/mypipeline"

  stub buildkite-agent "oidc request-token --audience ${audience} --lifetime 300 : echo faketoken"
  stub curl \
    "-s -w '\\n%{http_code}' -H 'Authorization: Bearer faketoken' 'https://api.buildkite.com/v2/analytics/organizations/myorg/suites/mypipeline' : echo '{}' ; echo 200"

  export BUILDKITE_PLUGIN_TESTS_INSTALL_CLIENT=false

  run $PWD/hooks/pre-command
  assert_success

  source ${BUILDKITE_ENV_FILE}
  assert_equal "${BUILDKITE_TEST_ENGINE_SUITE_SLUG}" mypipeline
  assert_equal "${BUILDKITE_ANALYTICS_TOKEN}" faketoken
  assert_equal "${BUILDKITE_TEST_ENGINE_API_ACCESS_TOKEN}" faketoken
}

@test "fails when pinned bktec version is too old for upload_results" {
  export BUILDKITE_ENV_FILE=$(mktemp)
  export BUILDKITE_ORGANIZATION_SLUG="myorg"
  export BUILDKITE_PIPELINE_SLUG="mypipeline"
  export BUILDKITE_PLUGIN_TESTS_CLIENT_VERSION=2.6.0
  export BUILDKITE_TEST_ENGINE_UPLOAD_RESULTS=true

  run $PWD/hooks/pre-command
  assert_failure
  assert_output --partial "Error: bktec 2.6.0 does not support upload_results"
}

@test "does not fail when pinned bktec version is too old but upload_results is disabled" {
  export BUILDKITE_ENV_FILE=$(mktemp)
  export BUILDKITE_ORGANIZATION_SLUG="myorg"
  export BUILDKITE_PIPELINE_SLUG="mypipeline"
  export BUILDKITE_PLUGIN_TESTS_CLIENT_VERSION=2.6.0
  export BUILDKITE_TEST_ENGINE_UPLOAD_RESULTS=false

  audience="https://buildkite.com/organizations/myorg/analytics/suites/mypipeline"
  tmpdir="/tmp/buildkite-plugin-test-engine/2.6.0/linux_amd64"
  tmpfile="${tmpdir}/bktec.1234567"

  stub buildkite-agent "oidc request-token --audience ${audience} --lifetime 300 : echo faketoken"
  stub mktemp "${tmpdir}/bktec.XXXXXXX : echo ${tmpfile}"
  stub curl \
    "-s -w '\\n%{http_code}' -H 'Authorization: Bearer faketoken' 'https://api.buildkite.com/v2/analytics/organizations/myorg/suites/mypipeline' : echo '{}' ; echo 200" \
    "-fL --progress-bar https://github.com/buildkite/test-engine-client/releases/download/v2.6.0/bktec_2.6.0_linux_amd64 -o ${tmpfile} : cp $PWD/tests/fixtures/bktec_2.6.0 ${tmpfile}" \
    "-sfL https://github.com/buildkite/test-engine-client/releases/download/v2.6.0/bktec_2.6.0_checksums.txt : cat $PWD/tests/fixtures/bktec_2.6.0_checksums.txt"
  export BUILDKITE_PLUGIN_TESTS_INSTALL_CLIENT=true

  run $PWD/hooks/pre-command
  assert_success
  refute_output --partial "Error: bktec 2.6.0 does not support upload_results"
}

@test "warns when existing bktec on PATH is too old for upload_results" {
  export BUILDKITE_ENV_FILE=$(mktemp)
  export BUILDKITE_ORGANIZATION_SLUG="myorg"
  export BUILDKITE_PIPELINE_SLUG="mypipeline"
  export BUILDKITE_TEST_ENGINE_UPLOAD_RESULTS=true

  audience="https://buildkite.com/organizations/myorg/analytics/suites/mypipeline"

  stub buildkite-agent "oidc request-token --audience ${audience} --lifetime 300 : echo faketoken"
  stub curl \
    "-s -w '\\n%{http_code}' -H 'Authorization: Bearer faketoken' 'https://api.buildkite.com/v2/analytics/organizations/myorg/suites/mypipeline' : echo '{}' ; echo 200"
  stub bktec \
    "--version : echo 'bktec version 2.6.0'"

  run $PWD/hooks/pre-command
  assert_success
  assert_output --partial "Warning: bktec 2.6.0 does not support upload_results"

  unstub bktec
}

@test "continues with a warning when get_suite returns an unexpected status" {
  export BUILDKITE_ENV_FILE=$(mktemp)
  export BUILDKITE_ORGANIZATION_SLUG="myorg"
  export BUILDKITE_PIPELINE_SLUG="mypipeline"

  audience="https://buildkite.com/organizations/myorg/analytics/suites/mypipeline"

  stub buildkite-agent \
    "oidc request-token --audience ${audience} --lifetime 300 : echo faketoken"
  stub curl \
    "-s -w '\\n%{http_code}' -H 'Authorization: Bearer faketoken' 'https://api.buildkite.com/v2/analytics/organizations/myorg/suites/mypipeline' : echo '{}' ; echo 500"

  export BUILDKITE_PLUGIN_TESTS_INSTALL_CLIENT=false

  run $PWD/hooks/pre-command
  assert_success
  assert_output --partial "Warning: could not confirm Test Suite exists"
}

@test "continues with a warning when create_suite returns an unexpected status" {
  export BUILDKITE_ENV_FILE=$(mktemp)
  export BUILDKITE_ORGANIZATION_SLUG="myorg"
  export BUILDKITE_PIPELINE_SLUG="mypipeline"

  suite_audience="https://buildkite.com/organizations/myorg/analytics/suites/mypipeline"
  org_audience="https://buildkite.com/myorg"

  stub buildkite-agent \
    "oidc request-token --audience ${suite_audience} --lifetime 300 : echo suitetoken" \
    "oidc request-token --audience ${org_audience} --lifetime 300 : echo orgtoken"
  stub curl \
    "-s -w '\\n%{http_code}' -H 'Authorization: Bearer suitetoken' 'https://api.buildkite.com/v2/analytics/organizations/myorg/suites/mypipeline' : echo '{}' ; echo 404" \
    "-s -w '\\n%{http_code}' -X POST -H 'Authorization: Bearer orgtoken' -H 'Content-Type: application/json' --data '{}' 'https://api.buildkite.com/v2/analytics/organizations/myorg/suites/create_from_pipeline' : echo '{}' ; echo 500"

  export BUILDKITE_PLUGIN_TESTS_INSTALL_CLIENT=false

  run $PWD/hooks/pre-command
  assert_success
  assert_output --partial "Warning: could not create Test Suite"
}

@test "downloads bktec using sed fallback when jq is unavailable" {
  export BUILDKITE_ENV_FILE=$(mktemp)
  export BUILDKITE_ORGANIZATION_SLUG="myorg"
  export BUILDKITE_PIPELINE_SLUG="mypipeline"
  export BUILDKITE_PLUGIN_TESTS_INSTALL_CLIENT=true

  audience="https://buildkite.com/organizations/myorg/analytics/suites/mypipeline"
  tmpdir="/tmp/bktec-sed-test/buildkite-plugin-test-engine/2.6.0/linux_amd64"
  tmpfile="${tmpdir}/bktec.1234567"

  stub buildkite-agent "oidc request-token --audience ${audience} --lifetime 300 : echo faketoken"
  stub mktemp "${tmpdir}/bktec.XXXXXXX : echo ${tmpfile}"
  stub curl \
    "-s -w '\\n%{http_code}' -H 'Authorization: Bearer faketoken' 'https://api.buildkite.com/v2/analytics/organizations/myorg/suites/mypipeline' : echo '{}' ; echo 200" \
    "-sf https://api.github.com/repos/buildkite/test-engine-client/releases/latest : cat $PWD/tests/fixtures/bktec-releases.json" \
    "-fL --progress-bar https://github.com/buildkite/test-engine-client/releases/download/v2.6.0/bktec_2.6.0_linux_amd64 -o ${tmpfile} : cp $PWD/tests/fixtures/bktec_2.6.0 ${tmpfile}" \
    "-sfL https://github.com/buildkite/test-engine-client/releases/download/v2.6.0/bktec_2.6.0_checksums.txt : cat $PWD/tests/fixtures/bktec_2.6.0_checksums.txt"

  jq_available() { return 1; }
  export -f jq_available
  run env TMPDIR="/tmp/bktec-sed-test" $PWD/hooks/pre-command
  unset -f jq_available

  assert_success
  assert_output --partial "bktec 2.6.0 (linux/amd64)"
}

@test "fails when latest bktec version cannot be parsed from GitHub API response" {
  export BUILDKITE_ENV_FILE=$(mktemp)
  export BUILDKITE_ORGANIZATION_SLUG="myorg"
  export BUILDKITE_PIPELINE_SLUG="mypipeline"
  export BUILDKITE_PLUGIN_TESTS_INSTALL_CLIENT=true

  audience="https://buildkite.com/organizations/myorg/analytics/suites/mypipeline"

  stub buildkite-agent "oidc request-token --audience ${audience} --lifetime 300 : echo faketoken"
  stub curl \
    "-s -w '\\n%{http_code}' -H 'Authorization: Bearer faketoken' 'https://api.buildkite.com/v2/analytics/organizations/myorg/suites/mypipeline' : echo '{}' ; echo 200" \
    "-sf https://api.github.com/repos/buildkite/test-engine-client/releases/latest : echo '{}'"

  run $PWD/hooks/pre-command

  assert_failure
  assert_output --partial "Error: could not parse latest bktec version from GitHub API response"
}

@test "downloads bktec when requested" {
  export BUILDKITE_ENV_FILE=$(mktemp)
  export BUILDKITE_ORGANIZATION_SLUG="myorg"
  export BUILDKITE_PIPELINE_SLUG="mypipeline"

  audience="https://buildkite.com/organizations/myorg/analytics/suites/mypipeline"
  tmpdir="/tmp/buildkite-plugin-test-engine/2.6.0/linux_amd64"
  tmpfile="${tmpdir}/bktec.1234567"

  stub buildkite-agent "oidc request-token --audience ${audience} --lifetime 300 : echo faketoken"
  stub mktemp "${tmpdir}/bktec.XXXXXXX : echo ${tmpfile}"
  stub curl \
    "-s -w '\\n%{http_code}' -H 'Authorization: Bearer faketoken' 'https://api.buildkite.com/v2/analytics/organizations/myorg/suites/mypipeline' : echo '{}' ; echo 200" \
    "-sf https://api.github.com/repos/buildkite/test-engine-client/releases/latest : cat $PWD/tests/fixtures/bktec-releases.json" \
    "-fL --progress-bar https://github.com/buildkite/test-engine-client/releases/download/v2.6.0/bktec_2.6.0_linux_amd64 -o ${tmpfile} : cp $PWD/tests/fixtures/bktec_2.6.0 ${tmpfile}" \
    "-sfL https://github.com/buildkite/test-engine-client/releases/download/v2.6.0/bktec_2.6.0_checksums.txt : cat $PWD/tests/fixtures/bktec_2.6.0_checksums.txt"
  export BUILDKITE_PLUGIN_TESTS_INSTALL_CLIENT=true

  source $PWD/hooks/pre-command

  assert_equal "${BUILDKITE_TEST_ENGINE_CLIENT_PATH}" /tmp/buildkite-plugin-test-engine/2.6.0/linux_amd64/bktec

  run "${BUILDKITE_TEST_ENGINE_CLIENT_PATH}"
  assert_output "fake bktec"
}

