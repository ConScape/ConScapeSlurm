using Test
using ConScapeSlurm
using ConScape
using Rasters
using JSON3

@testset "ConScapeSlurm" begin
    include("slurm.jl")
    include("batch_integration.jl")
end
