using Test
using ConScape
using ConScape: ColumnSolver, FunctionalHabitat, MovementFlow
using ConScape: RandomisedShortestPath, ExpectedCost, ConScapeProblem, BatchProblem, WindowedProblem
using ConScapeSlurm
using Rasters
using JSON3

# Use ConScape's test data (same setup as ConScape/test/windowed.jl)
datadir = joinpath(dirname(pathof(ConScape)), "..", "data")

@testset "Batch Integration" begin
    # Set up test raster data (matching ConScape's test/windowed.jl exactly)
    θ = 0.1
    landscape = "sno_2000"
    steplikelihood = reverse(rotr90(Raster(joinpath(datadir, "affinities_$landscape.asc"); missingval=NaN)); dims=X)
    quality = reverse(rotr90(Raster(joinpath(datadir, "qualities_$landscape.asc"); missingval=NaN)); dims=X)
    quality[(steplikelihood .> 0) .& isnan.(quality)] .= 1e-20
    rast = RasterStack((; steplikelihood, quality))

    # Define problem (matching ConScape's test pattern)
    measures = (;
        betm=MovementFlow(),
        fh=FunctionalHabitat(),
    )
    distance_transformation = x -> exp(-x / 50)
    movement = RandomisedShortestPath(ExpectedCost();
        theta=θ,
        distance_transformation
    )
    solver = ColumnSolver()
    csp = ConScapeProblem(; measures, movement, solver)

    kw = (; buffer=10, centersize=5)

    @testset "BatchProblem assessment and solve" begin
        # Create batch problem (matching ConScape's test pattern)
        batch_problem = BatchProblem(csp; datapath=tempname(), kw...)

        # Run assessment
        assessment = ConScape.assess(batch_problem, rast)
        @test assessment isa ConScape.WindowAssessment
        @test assessment.njobs > 0
        @test assessment.njobs == 39  # Expected from ConScape tests

        # Simulate running first few tasks
        for task_idx in 1:min(assessment.njobs, 3)
            solve(batch_problem, rast, assessment, task_idx; verbose=false)
        end
    end

    @testset "Reassessment after partial completion" begin
        batch_problem = BatchProblem(csp; datapath=tempname(), kw...)
        assessment = ConScape.assess(batch_problem, rast)

        # Run only task 1
        solve(batch_problem, rast, assessment, 1; verbose=false)

        # Reassess should show n-1 jobs remaining
        reassessment = ConScape.reassess(batch_problem, assessment)
        @test reassessment.njobs == assessment.njobs - 1
    end

    @testset "JSON assessment serialization" begin
        tempdir = mktempdir()
        batch_problem = BatchProblem(csp; datapath=tempdir, kw...)
        assessment = ConScape.assess(batch_problem, rast)

        # Write assessment to JSON (like assess.jl does)
        assessment_path = joinpath(tempdir, "assessment.json")
        JSON3.write(assessment_path, assessment)

        # Read it back (like run.jl does)
        loaded_assessment = JSON3.read(read(assessment_path, String), ConScape.WindowAssessment)

        @test loaded_assessment.njobs == assessment.njobs
        @test loaded_assessment.shape == assessment.shape
        @test loaded_assessment.indices == assessment.indices

        rm(tempdir; recursive=true)
    end

    @testset "Full batch workflow" begin
        tempdir = mktempdir()
        batch_problem = BatchProblem(csp; datapath=tempdir, kw...)

        # Phase 1: Assessment (like assess.jl)
        assessment = ConScape.assess(batch_problem, rast)
        JSON3.write(joinpath(tempdir, "assessment.json"), assessment)
        @test assessment.njobs == 39

        # Phase 2: Run all jobs (simulating SLURM array)
        for job in 1:assessment.njobs
            solve(batch_problem, rast, assessment, job; verbose=false)
        end

        # Phase 3: Reassess (like reassess.jl)
        reassessment = ConScape.reassess(batch_problem, assessment)
        @test reassessment.njobs == 0  # All jobs completed

        # Phase 4: Mosaic (like mosaic.jl)
        result = mosaic(batch_problem; to=rast)
        @test result isa RasterStack
        @test haskey(result, :betm)
        @test haskey(result, :fh)

        rm(tempdir; recursive=true)
    end
end
