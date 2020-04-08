#!/bin/bash
#
# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eu pipefail

shopt -s nullglob

missing_var=""
# Ensure all required env vars are supplied.
for var in DIRECTORY_NAME CLOUDBUILD_NAME PROJECT; do
  if ! [[ -v "$var" ]]; then
    echo "$var env variable is required"
    missing_var=true
  fi
done

if [[ -n "$missing_var" ]]; then
  exit 1
fi

function trigger_exist {
  local -r solution=$1

  echo "$triggers" | jq -e --arg filename "${CLOUDBUILD_NAME}" --arg solution "${solution}" \
      '.[] | select(.filename == $filename) | select(.substitutions._SOLUTION_NAME == $solution)'
  return $?
}

function main {
  local -i failure_cnt=0

  triggers="$(gcloud alpha builds triggers list --project="${PROJECT}" --format json)"
  for solution in ${DIRECTORY_NAME}/*; do
    if [[ -d ${solution} ]]; then
      solution="${solution%/}"     # strip trailing slash
      solution="${solution##*/}"   # strip path and leading slash

      set +e
      trigger_exist "${solution}"
      local -i status_code=$?
      set -e

      if [[ ${status_code} -gt 0 ]]; then
        echo "[${solution}] FAIL"
        (( failure_cnt+=1 ))
      else
        echo "[${solution}] PASS"
      fi
    fi
  done

  echo "*************************************************************"
  echo "* Done with results: ${failure_cnt} failure(s)."
  echo "* For more information, see https://github.com/GoogleCloudPlatform/click-to-deploy/blob/master/triggers/README.md"
  echo "*************************************************************"
  
  return ${failure_cnt}
}

main "$@"
