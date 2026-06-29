function settings(name=nothing) 
    isnothing(name) && length(ARGS) == 0 &&
        throw(ArgumentError("""
            no `name` or ARGS

            Please specify the dataset name on the command line, e.g. sbatch run.sh dataset_name. 
            This should match a line in the `dataset_name` column of user/datasets.csv
            """))

    df = CSV.read(datasets_csv_path(), DataFrame)
    checkdatasets(df, name)
    dataset_name = isnothing(name) ? ARGS[1] : name
    println("Using dataset $dataset_name...")
    filter(df) do row
        row.dataset_name == dataset_name
    end[1, :]
end

path(args...)::String = settings(args...)["path"]::String
assessment_path(args...) = joinpath(path(args...), "assessment.json")
original_assessment_path(args...) = joinpath(path(args...), "original_assessment.json")
estimates_path(args...) = joinpath(path(args...), "estimates.json")
datasets_csv_path(args...) = joinpath(@__DIR__, "../user", "datasets.csv")

function checkdatasets(df, name=nothing)
    DataFrames.nrow(df) > 0 || throw(ArgumentError("`user/datasets.csv` is empty: specify your datasets first."))
    "dataset_name" in names(df) || throw(ArgumentError("No `dataset_name` column in datasets.csv"))
    if !isnothing(name)
        name in df.dataset_name || throw(ArgumentError("Name $name not found in dataset_name column $(df.dataset_name)"))
    end
    return true
end

function assessment(args...) 
    path = assessment_path(args...) 
    isfile(path) || error("Assessment not found at $path. Did you run assess.sh first?")
    JSON3.read(path, ConScape.NestedAssessment) 
end
function original_assessment(args...) 
    path = original_assessment_path(args...)
    isfile(path) || error("Assessment not found at $path. Did you run assess.sh first?")
    JSON3.read(path, ConScape.NestedAssessment) 
end

function ConScape.assess(args...)
    datadir = ConScapeSlurm.path(args...)
    isdir(datadir) || error("Data path $datadir not found, check your datasets.csv file")
    assessment_path = ConScapeSlurm.assessment_path(args...)
    original_assessment_path = ConScapeSlurm.original_assessment_path(args...)

    println("Loading problem...")
    batch_problem = ConScapeSlurm.batch_problem(args...)
    rast = ConScapeSlurm.raster(args...)
    println("RasterStack of size $(size(rast)) loaded lazily")

    println("Running ConScape.assess...")
    @time assessment = ConScape.assess(batch_problem, rast; verbose=true)

    JSON3.write(assessment_path, assessment)
    JSON3.write(original_assessment_path, assessment)

    return assessment
end

function raster(args...)
    settings = ConScapeSlurm.settings(args...)
    datadir = settings["path"]
    source_qualities_path = joinpath(datadir, settings["source_qualities"])
    target_qualities_path = joinpath(datadir, settings["target_qualities"])
    affinities_path = joinpath(datadir, settings["affinities"])
    pad = settings["buffer"]::Int

    # Load rasters lazily
    source_qualities = Raster(source_qualities_path; lazy=true, missingval=NaN)
    target_qualities = Raster(target_qualities_path; lazy=true, missingval=NaN)
    affinities = Raster(affinities_path; lazy=true, missingval=NaN)
    
    # Here we assume affinities and qualities are the same
    st = RasterStack((; source_qualities, target_qualities, affinities))
    # Pad the raster border with the buffer size
    return DiskArrays.pad(st, (X=(pad, pad), Y=(pad, pad)); fill=NaN)
end
    
function batch_problem(args...;
    nwindows=nothing,
    buffer=nothing,
    centersize=nothing, 
    threaded=true,
)
    # Read window parameters from file if they were not passed in
    settings = ConScapeSlurm.settings(args...)
    datapath = joinpath(settings["path"], "outputs")
    buffer = (isnothing(buffer) ? settings["buffer"] : buffer)::Int
    nwindows = (isnothing(nwindows) ? settings["nwindows"] : nwindows)::Int
    centersize = (isnothing(centersize) ? settings["centersize"] : centersize)::Int

    # Specify the windowing pattern
    windowed_problem = ConScape.WindowedProblem(problem(args...); 
        buffer, centersize, threaded, shape=:circle
    )

    # Specify the batch job windowing
    return BatchProblem(windowed_problem; datapath, nwindows)
end
