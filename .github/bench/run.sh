#!/usr/bin/env bash
# Clean + incremental Signal Debug device build (unsigned) (port of Bitrise _signal_benchmark).
set -eo pipefail
source "$(dirname "$0")/lib.sh"
cd "$GITHUB_WORKSPACE"
LOGS="$BENCH_OUT/logs"; mkdir -p "$LOGS"

timed_build() { # $1 = derived data, $2 = log
  local start end xc
  start=$(now)
  xcodebuild -workspace Signal.xcworkspace -scheme "$SIGNAL_SCHEME" -configuration "$SIGNAL_CONFIGURATION" \
    -destination generic/platform=iOS -derivedDataPath "$1" -clonedSourcePackagesDirPath "$SPM_DIR" \
    -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    build > "$2" 2>&1 || { tail -n 80 "$2" >&2; return 1; }
  end=$(now); xc=$(xc_seconds "$2")
  if [ -n "$xc" ]; then echo "$xc"; else python3 -c "print(round($end-$start,3))"; fi
}

echo "project,metric_key,machine_key,run,duration_sec" > "$BENCH_OUT/results.csv"
: > "$BENCH_OUT/clean.txt"; : > "$BENCH_OUT/incremental.txt"
for i in $(seq 1 $(( WARMUP_RUNS + BENCHMARK_RUNS ))); do
  run_label "$i"; DD="$RUNNER_TEMP/signal-dd"; rm -rf "${DD:?}"  # same path every run, so path-dependent cache keys match
  echo "=== $LABEL: clean build ==="
  CLEAN=$(timed_build "$DD" "$LOGS/$LABEL-clean.log"); echo "clean: ${CLEAN}s"
  printf '\n// benchmark incremental change %s\n' "$LABEL" >> "$INCREMENTAL_FILE"
  INCR=$(timed_build "$DD" "$LOGS/$LABEL-incremental.log"); git checkout -- "$INCREMENTAL_FILE"; echo "incremental: ${INCR}s"
  echo "${BENCHMARK_PROJECT},clean_build,${MACHINE_KEY},${LABEL},${CLEAN}" >> "$BENCH_OUT/results.csv"
  echo "${BENCHMARK_PROJECT},incremental_build,${MACHINE_KEY},${LABEL},${INCR}" >> "$BENCH_OUT/results.csv"
  if [ "$MEASURED" = 1 ]; then echo "$CLEAN" >> "$BENCH_OUT/clean.txt"; echo "$INCR" >> "$BENCH_OUT/incremental.txt"; fi
  rm -rf "${DD:?}"
done

cat > "$BENCH_OUT/summary.json" <<JSON
{
$(summary_common),
  "benchmark_revision": "$(source_rev)",
  "clean_build": $(stats "$BENCH_OUT/clean.txt"),
  "incremental_build": $(stats "$BENCH_OUT/incremental.txt")
}
JSON
(cd "$BENCH_OUT" && rm -f clean.txt incremental.txt)
finish
