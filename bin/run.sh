#!/usr/bin/env bash

# Synopsis:
# Run the test runner on a solution.

# Arguments:
# $1: exercise slug
# $2: path to solution folder
# $3: path to output directory

# Output:
# Writes the test results to a results.json file in the passed-in output directory.
# The test results are formatted according to the specifications at https://github.com/exercism/docs/blob/main/building/tooling/test-runners/interface.md

# Example:
# ./bin/run.sh two-fer path/to/solution/folder/ path/to/output/directory/

# If any required arguments is missing, print the usage and exit
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "usage: $0 exercise-slug path/to/solution/folder/ path/to/output/directory/"
    exit 1
fi

slug="$1"
solution_dir=$(realpath "${2%/}")
output_dir=$(realpath "${3%/}")
results_file="${output_dir}/results.json"

cd "${solution_dir}" || exit 1

# Create the output directory if it doesn't exist
mkdir -p "${output_dir}"

echo "${slug}: testing..."

# Run the tests for the provided implementation file and redirect stdout and
# stderr to capture it
compile_options=(
    # ref https://odin-lang.org/docs/testing/#compile-time-options
    -define:ODIN_TEST_LOG_LEVEL=warning
    -define:ODIN_TEST_SHORT_LOGS=true 
    -define:ODIN_TEST_FANCY=false
    -define:ODIN_TEST_RANDOM_SEED=1234567890
    -define:ODIN_TEST_TRACK_MEMORY=false
)

raw_output=$( odin test . "${compile_options[@]}"  2>&1 )
rc=$?

# Write the results.json file based on the exit code of the command that was 
# just executed that tested the implementation file
if [ $rc -eq 0 ]; then
    jq -n '{version: 1, status: "pass"}' > "${results_file}"
else
    # Sanitize the output:
    # remove text that can change from run to run, or from system to system.
    test_output=$(
        gawk -v pwd="${PWD}/" '
            /To run only the failed test,/ {exit}
            /Finished [[:digit:]]+ tests in / { sub(/ in [[:digit:].]+.s/, "") }
            {
                gsub(pwd, "") # trim full paths from filenames
                print
            }
        ' <<< "$raw_output"
    )

    if [[ $test_output =~ .*$'\nFinished '[[:digit:]]+' tests.'.* ]]; then
        # successfully compiled, but test failures
        status='fail'
    else
        status='error'
    fi

    # OPTIONAL: Manually add colors to the output to help scanning the output for errors
    # If the test output does not contain colors to help identify failing (or passing)
    # tests, it can be helpful to manually add colors to the output
    # colorized_test_output=$(echo "${test_output}" \
    #      | GREP_COLOR='01;31' grep --color=always -E -e '^(ERROR:.*|.*failed)$|$' \
    #      | GREP_COLOR='01;32' grep --color=always -E -e '^.*passed$|$')

    jq -n --arg output "${test_output}" \
          --arg status "${status}" \
        '{version: 1, status: $status, message: $output}' > "${results_file}"
fi

echo "${slug}: done"
