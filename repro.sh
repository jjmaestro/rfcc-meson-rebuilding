#!/bin/bash

set -euo pipefail

LOGDIR="logs/rebuilding"

_bazel_build() {
    local i="$1"; shift

    local bazel_build_args=(
        "--verbose_failures"
        "--verbose_explanations"
        "--sandbox_debug"
    )

    local execlog="$LOGDIR/execution_log-$i.json"
    bazel_build_args+=(
        "--explain=$LOGDIR/explain-$i.log"
        "--execution_log_json_file=$execlog"
    )

    mkdir -p "$LOGDIR"

    local cmd="bazel build ${bazel_build_args[*]} //example:meson"

    echo -e "\n$cmd\n"
    eval "$cmd"

    bazel query \
        "deps('//example:meson')" \
        --output=build > "$LOGDIR/query-build-$i.log"
}

bazel_build_all() {
    bazel clean --expunge

    for i in $(seq 3); do
        _bazel_build "$i"
    done

    echo
    echo "wc -l $LOGDIR/*"
    wc -l "$LOGDIR"/*
}

_fix_json() {
    local file="$1"; shift

    ############ HACK ############
    # https://github.com/bazelbuild/bazel/issues/14209
    # there was a diff https://github.com/jschear/bazel/commit/225540b79751570c912dc989d239ffb4cbb56fb8
    # but it doesn't seem to have made it to Bazel o.0
    grep -qE '^\[' "$file" && return

    sed -i '.tmp' '1s|^|[|; $s|$|]|; s|^}$|},|; s|}{|},{|;' "$file"
    jq -S '.' "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
    ############ HACK ############
}

compare_rebuilding_inputs() {
    local execlog1="$LOGDIR"/execution_log-1.json
    _fix_json "$execlog1"

    local execlog2="$LOGDIR"/execution_log-2.json
    _fix_json "$execlog2"

    echo "$execlog1"
    jq '.[].targetLabel' "$execlog1"

    echo

    echo "$execlog2"
    jq '.[].targetLabel' "$execlog2"

    # filter for the '//example:meson' since that's what's in the second execlog

    local inputs1="$LOGDIR"/execution_log-1.example_meson.inputs.json
    jq -S '
        .[] | select(.targetLabel == "//example:meson") | .inputs
    ' "$execlog1" > "$inputs1"

    local inputs2="$LOGDIR"/execution_log-2.example_meson.inputs.json
    jq -S '
        .[] | select(.targetLabel == "//example:meson") | .inputs
    ' "$execlog2" > "$inputs2"

    # finally, check the differences
    echo
    echo "diff inputs..."

    local inputs_diff="$LOGDIR"/execution_log-example_meson.inputs.diff
    diff -brauN "$inputs1" "$inputs2" > "$inputs_diff" || true

    head -n 20 "$inputs_diff"
    echo -e "\n(...)\n"
    tail -n 20 "$inputs_diff"

    echo

    local cmd

    cmd="grep '^- ' \"$inputs_diff\" | wc -l"
    echo -e "\n$cmd"
    eval "$cmd" || true

    cmd="grep '^+ ' \"$inputs_diff\" | wc -l"
    echo -e "\n$cmd"
    eval "$cmd" || true

    cmd="grep '^+ ' \"$inputs_diff\" | grep pyc | grep -v '311\.pyc'"
    echo -e "\n$cmd"
    eval "$cmd" || true
}

"$@"
