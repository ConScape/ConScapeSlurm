#!/bin/bash
#SBATCH --account=nn11055k
#SBATCH --job-name='assessCS'
#SBATCH --time=1:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=1G
set -o errexit  # Exit the script on any error
set -o nounset  # Treat any unset variables as an error
module --quiet purge   # clear any inherited modules
module load Julia/1.12.2
julia --threads=auto --project=.. assess.jl $1