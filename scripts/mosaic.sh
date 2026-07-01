#!/bin/bash
#SBATCH --account=nn11055k
#SBATCH --job-name='mosaicCS'
#SBATCH --time=2:00:0
#SBATCH --mem-per-cpu=4G 
#SBATCH --cpus-per-task=1
#SBATCH --ntasks=1                
set -o errexit  # Exit the script on any error
set -o nounset  # Treat any unset variables as an error
module --quiet purge   # clear any inherited modules
module load Julia/1.12.2
julia --threads=1 --project=.. mosaic.jl $1