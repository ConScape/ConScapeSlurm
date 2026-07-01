using Rasters
using ConScape
import ConScapeSlurm

datadir = ConScapeSlurm.path()

# Load problem and raster
batch_problem = ConScapeSlurm.batch_problem()
rast = ConScapeSlurm.raster()
original_assessment = ConScapeSlurm.original_assessment()

pad = ConScapeSlurm.settings()["buffer"]::Int

# Get all the filepaths that we made raster files for
paths = filter(isdir, ConScape.batch_paths(batch_problem, rast)[original_assessment.indices])

# Create lazy RasterStacks for all of them
stacks = RasterStack.(paths; lazy=true, missingval=NaN)
GC.gc()

# Create a zeroed out RasterStack to mosaic into.
# It will have layer names matching the measures, 
# each with NaNs where quality is NaN and zeros elsewhere
# This is all lazy because `rast` is lazy. It liekely would not fit in RAM
# The view is to unpad the padded rasters and get the original size
zeroed_qualities = map(ConScape.measures(batch_problem)) do _
    (@view rast.sourcequality[pad+1:end-pad, pad+1:end-pad]) .* 0
end |> RasterStack

# Write the destination rasters
# Some care is needed here, both in making a file that is easy to use later
# and in making the mosaic faster. If we chunk it is much faster because
# Each mosaic only writes to a small area rather than whole columns.
# This will also make reading subsets faster for users of the data.
filename = joinpath(datadir, "output.tif")
dest_filenames = write(filename, zeroed_qualities; 
    options="BIGTIFF" => "YES", # In case its larger than 4GB, but also faster somehow
    chunks=(128, 128), # 128 is faster than 256 and much faster than the default columns
    missingval=NaN, # Make sure the missing value is NaN
    force=true, # Overwrite if it already exists
)

# Read the new rasters lazily to `dest`
dest = RasterStack(dest_filenames; 
    lazy=true, # Only load metadata, data stays on disk
    missingval=NaN # Make sure the missing value is NaN, not `missing`
)

# Mosaic all stacks into `dest`
@time open(dest; write=true) do D
    mosaic!(sum, D, stacks; 
        read=true, # Read every region from disk before the mosaic
        gc=50, # Garbage collect every 50th raster to control memory use
    );
end

# Show the chunk pattern in the output
display(Rasters.eachchunk(dest.fh))