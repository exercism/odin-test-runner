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

#------------------------------------------------------------
# Some global variables (passing arrays in bash is annoying)
declare -A odin_test_results
declare -A descriptions
declare -A task_ids
declare -A test_code
declare -A failure_messages
declare -a test_names
declare test_report_file
declare results_file

#------------------------------------------------------------
# Some utility procs
die() { echo "$*" >&2; exit 1; }

usage() {
    die "usage: $0 exercise-slug path/to/solution/folder/ path/to/output/directory/"
}

run_tests() {
    local compile_options=(
        # Ref https://odin-lang.org/docs/testing/#compile-time-options
        -define:ODIN_TEST_LOG_LEVEL=warning
        -define:ODIN_TEST_SHORT_LOGS=true
        -define:ODIN_TEST_FANCY=false
        -define:ODIN_TEST_RANDOM_SEED=1234567890
        -define:ODIN_TEST_TRACK_MEMORY=false
        -define:ODIN_TEST_JSON_REPORT="${test_report_file}"
    )

    rm -f "$test_report_file"
    odin test . "${compile_options[@]}"  2>&1
}

# Sanitize the output:
# remove text that can change from run to run, or from system to system.
sanitize_odin_test_output() {
    gawk -v pwd="${PWD}/" '
        /To run only the failed test,/ {exit}
        /Finished [[:digit:]]+ tests in / { sub(/ in [[:digit:].]+.s/, "") }
        {
            gsub(pwd, "") # trim full paths from filenames
            print
        }
    '
}

join() {
    local IFS="$1"
    shift
    echo "$*"
}

#------------------------------------------------------------
write_results_v1() {
    local test_output=$1 rc=$2

    # Write the results.json file based on the exit code of the command that was
    # just executed that tested the implementation file
    if (( rc == 0 )); then
        jq -n '{version: 1, status: "pass"}' > "${results_file}"
    else
        if [[ $test_output =~ .*$'\nFinished '[[:digit:]]+' tests.'.* ]]; then
            # Successfully compiled, but test failures
            status='fail'
        else
            status='error'
        fi

        jq -n --arg output "${test_output}" \
              --arg status "${status}" \
            '{version: 1, status: $status, message: $output}' > "${results_file}"
    fi
}

#------------------------------------------------------------
write_results_v2() {
    local package_name=$1 rc=$2 test_output=$3

    if [[ ! -f $test_report_file ]]; then
        # Compilation error: `odin test` did not create the file
        jq  -n \
            --argjson version 3 \
            --arg     status  "error" \
            --arg     message "$test_output" \
            '$ARGS.named' > "${results_file}"
        return
    fi

    # Read the JSON report file that `odin test` spits out
    get_odin_test_statuses

    # Parse the test.odin file
    read_test_file

    # Get failure messages from the test output
    parse_odin_test_output "${test_output}"

    # Now, we can actually compose the results.json file
    local status=pass
    if (( rc != 0 )); then status=fail; fi

    jq  -n \
        --argjson version 3 \
        --arg     status  "$status" \
        --argjson tests   "$(compose_test_results)" \
        '$ARGS.named' > "${results_file}"
}

compose_test_results() {
    local json='[]' test_name status
    local -a args

    for test_name in "${test_names[@]}"; do
        args=( --arg name "${descriptions["$test_name"]}" )
        if [[ -v "odin_test_results[$test_name]" ]] && "${odin_test_results["$test_name"]}"; then
            status=pass
        else
            status=fail
            if [[ -v "failure_messages[$test_name]" ]]; then
                args+=( --arg message "${failure_messages[$test_name]}" )
            else
                args+=( --arg message "unknown" )   # TODO, more needed here
            fi
        fi
        args+=( --arg status "$status" )

        if [[ -v "test_bodies[$test_name]" ]]; then
            args+=( --arg test_code "${test_bodies["$test_name"]}" )
        fi

        if [[ -v "task_ids[$test_name]" ]]; then
            args+=( --arg task_id "${task_ids["$test_name"]}" )
        fi

        if [[ -v "test_code[$test_name]" ]]; then
            args+=( --arg test_code "${test_code["$test_name"]}" )
        fi

        # Add this test result to the array
        json=$( jq "${args[@]}" '. += [$ARGS.named]' <<< "$json" )
    done

    echo "${json}"
}

# Populate the global `odin_test_results` map
get_odin_test_statuses() {
    local name status

    while IFS=$'\t' read -r name status; do
        odin_test_results["$name"]=$status
    done < <(
        jq -r --arg package "$package_name" '
            .packages[$package][] | [.name, .success] | @tsv
        ' "${test_report_file}"
    )
}

# Parse the test.odin file to get the canonical order of the tests. 
# Populates the global maps:
# - descriptions
# - task_ids
# - test_code
read_test_file() {
    # People working locally might edit the test file and they might
    # accidentally submit it. In the future we might want to think about
    # parsing the test.odin using Odin.

    local -a test_body
    local in_test=false in_proc=false
    local test_file test_name test_body description task_id trimmed

    for test_file in ./*_test.odin; do
        while IFS= read -r line; do
            if ! "$in_test"; then
                if [[ $line == '@(test)' ]]; then
                    test_body=()
                    description=''
                    task_id=''
                    in_test=true
                fi
            else
                if [[ $line =~ ^'/// description = '(.+) ]]; then
                    description=${BASH_REMATCH[1]}
                elif [[ $line =~ ^'/// task_id = '(.+) ]]; then
                    task_id=${BASH_REMATCH[1]}
                elif [[ $line =~ ([[:alnum:]_]+)' :: proc' ]]; then
                    test_name=${BASH_REMATCH[1]}
                    if [[ -n $description ]]; then
                        descriptions["$test_name"]=$description
                    else
                        descriptions["$test_name"]=$test_name
                    fi
                    [[ -n $task_id ]] && task_ids["$test_name"]=$task_id
                    test_names+=( "$test_name" )
                    in_proc=true
                elif [[ $line == '}' ]]; then
                    in_test=false
                    in_proc=false
                    # shellcheck disable=SC2034
                    test_code["$test_name"]=$( join $'\n' "${test_body[@]}" )
                elif $in_proc; then
                    read -r trimmed <<< "$line"
                    [[ -n $trimmed ]] && test_body+=( "$trimmed" )
                fi
            fi
        done < "${test_file}"
    done
}

# Populates the global `failure_messages` map
parse_odin_test_output() {
    local test_output=$1
    local -a failure_message
    local seen_finished=false
    test_name=''

    while IFS= read -r line; do
        if ! $seen_finished; then
            if [[ $line == "Finished "*" tests. "*" test"*"failed." ]]; then
                seen_finished=true
            fi
        else
            if [[ $line =~ ^" - ${package_name}."([[:alnum:]_]+)[[:blank:]]+(.*) ]]; then
                # Start of test report
                if [[ -n $test_name && -n "$failure_message" ]]; then
                    failure_messages["$test_name"]=$(join $'\n' "${failure_message[@]}")
                fi
                test_name=${BASH_REMATCH[1]}
                failure_message=( "${BASH_REMATCH[2]}" )
            else
                # Midst of a test report
                failure_message+=( "$line" )
            fi
        fi
    done <<< "$test_output"
    if [[ -n $test_name && -n "${failure_message[*]}" && ! -v "failure_messages[$test_name]" ]]; then
        failure_messages["$test_name"]=$(join $'\n' "${failure_message[@]}")
    fi
}

#------------------------------------------------------------
main() {
    # If any required arguments is missing, print the usage and exit
    [[ -n "$1" && -n "$2" && -n "$3" ]] || usage

    local slug solution_dir output_dir results_file
    slug="$1"
    solution_dir=$(realpath "$2")
    output_dir=$(realpath "$3")

    [[ -d ${solution_dir} && -d ${output_dir} ]] || usage

    cd "${solution_dir}" || exit 1
    mkdir -p "${output_dir}"

    test_report_file="${output_dir}/tests.json"
    results_file="${output_dir}/results.json"

    echo "${slug}: testing..."

    # Run the tests here
    local raw_output rc
    raw_output=$( run_tests )
    rc=$?

    local sanitized_output
    sanitized_output=$(sanitize_odin_test_output <<< "${raw_output}")

    # Then process the results
    ## write_results_v1 "${sanitized_output}" "${rc}"
    write_results_v2 "${slug//-/_}" "${rc}" "${sanitized_output}"

    echo "${slug}: done"

    # If the built executable remains, delete it
    rm -f "${slug}"
}

main "$@"
