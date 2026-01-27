using Test

@testset "SLURM Task Index" begin
    # Save original env
    original_slurm = get(ENV, "SLURM_ARRAY_TASK_ID", nothing)

    # Clean state
    delete!(ENV, "SLURM_ARRAY_TASK_ID")

    @testset "parse SLURM_ARRAY_TASK_ID" begin
        # Test the parsing logic used in scripts/run.jl
        idkey = "SLURM_ARRAY_TASK_ID"

        # Default when not set
        batch = if haskey(ENV, idkey)
            parse(Int, ENV[idkey]) + 1
        else
            1
        end
        @test batch == 1

        # Test with various values (0-indexed from SLURM -> 1-indexed for Julia)
        ENV["SLURM_ARRAY_TASK_ID"] = "0"
        batch = parse(Int, ENV[idkey]) + 1
        @test batch == 1

        ENV["SLURM_ARRAY_TASK_ID"] = "5"
        batch = parse(Int, ENV[idkey]) + 1
        @test batch == 6

        ENV["SLURM_ARRAY_TASK_ID"] = "99"
        batch = parse(Int, ENV[idkey]) + 1
        @test batch == 100

        delete!(ENV, "SLURM_ARRAY_TASK_ID")
    end

    @testset "task index helper function" begin
        # Helper function that can be shared across platforms
        function get_task_index()
            if haskey(ENV, "SLURM_ARRAY_TASK_ID")
                return parse(Int, ENV["SLURM_ARRAY_TASK_ID"]) + 1
            else
                return 1
            end
        end

        # Default
        @test get_task_index() == 1

        # With SLURM env var
        ENV["SLURM_ARRAY_TASK_ID"] = "10"
        @test get_task_index() == 11

        ENV["SLURM_ARRAY_TASK_ID"] = "0"
        @test get_task_index() == 1

        delete!(ENV, "SLURM_ARRAY_TASK_ID")
    end

    # Restore original env
    if !isnothing(original_slurm)
        ENV["SLURM_ARRAY_TASK_ID"] = original_slurm
    else
        delete!(ENV, "SLURM_ARRAY_TASK_ID")
    end
end
