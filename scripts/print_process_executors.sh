#!/usr/bin/env bash

# Print the executor used for each submitted process by parsing .nextflow.log.
# Usage: ./scripts/print_process_executors.sh [path/to/.nextflow.log]

set -euo pipefail

log_file="${1:-.nextflow.log}"

if [[ ! -f "$log_file" ]]; then
  echo "Log file '$log_file' not found" >&2
  exit 1
fi

grep -E "Launch cmd line|Submitted process" "$log_file" | \
awk '
  /Launch cmd line/ {
    if ($0 ~ /local\.LocalTaskHandler/)      executor="local"
    else if ($0 ~ /grid\.GridTaskHandler/)   executor="slurm"
    else if ($0 ~ /awsbatch\.AwsBatchTaskHandler/) executor="awsbatch"
    else if ($0 ~ /k8s\.K8sTaskHandler/)     executor="k8s"
    else                                     executor="unknown"
  }
  /Submitted process/ {
    match($0, /> ([^ ]+)/, m)
    proc=m[1]
    sub(/ \(.*/, "", proc)
    printf "%-25s %s\n", proc, executor
  }
'
