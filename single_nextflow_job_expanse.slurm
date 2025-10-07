#!/bin/bash
#SBATCH -A sds166          # e.g. csdXXXX
#SBATCH -p debug                      # Expanse debug queue
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16            # tune for your test size
#SBATCH --mem=64G
#SBATCH -t 00:05:00                   # debug walltime limit
#SBATCH -J nf_local_debug
#SBATCH -o logs/%x-%j.out
#SBATCH -e logs/%x-%j.err

set -euo pipefail
export OUTPUT_FOLDER='output_single'
mkdir -p logs $OUTPUT_FOLDER

# ------------------------------
# Paths
# ------------------------------
# Persistent Nextflow directories on Lustre for -resume and caching
export NXF_WORK="/expanse/lustre/scratch/$USER/temp_project/work"
export NXF_HOME="/expanse/lustre/scratch/$USER/temp_project/.nextflow"
# Node-local scratch for ALL temporary files
export SCRATCH_DIR="/scratch/$USER/job_${SLURM_JOB_ID}"
mkdir -p "$SCRATCH_DIR" "$SCRATCH_DIR/tmp" "$SCRATCH_DIR/nxf_tmp" "$OUTPUT_FOLDER"

# ------------------------------
# Environment via micromamba (initialized in ~/.bashrc)
# ------------------------------
eval "$(micromamba shell hook --shell bash)"
micromamba activate nf-env

echo "[INFO] Activated env: ${CONDA_DEFAULT_ENV:-unknown}"
echo "[INFO] Nextflow path: $(command -v nextflow)"
command -v nextflow >/dev/null 2>&1 || { echo "[ERROR] nextflow not found after activating nf-env" >&2; exit 1; }

# ------------------------------
# Nextflow temp configuration (node-local)
# ------------------------------
export NXF_TEMP="$SCRATCH_DIR/nxf_tmp"
export TMPDIR="$SCRATCH_DIR/tmp"
export NXF_OPTS="-Djava.io.tmpdir=${TMPDIR}"
# Disable ANSI progress/ticker in Nextflow logs
export NXF_ANSI_LOG=false

# Mirror Slurm resources inside Nextflow automatically via env
export SLURM_CPUS_PER_TASK
export SLURM_MEM_PER_NODE

# ------------------------------
# Run Nextflow on the allocated node (local executor)
# ------------------------------
echo "[INFO] Job started at: $(date)"
srun --ntasks=1 nextflow run hello-workflow-4.nf \
  -with-report $OUTPUT_FOLDER/report.html \
  -with-trace $OUTPUT_FOLDER/trace.txt \
  -with-timeline $OUTPUT_FOLDER/timeline.html

# add this to nextflow run to use cached results
# -resume

echo "[INFO] Job completed at: $(date)"
