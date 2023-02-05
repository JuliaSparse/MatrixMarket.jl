#Attempts to read every .mtx file in the test directory
using MatrixMarket
using CodecZlib
using SparseArrays
using SHA
using Test

const TEST_PATH = @__DIR__

tests = [
    "mtx",
    "dl-matrixmarket",
]

@testset "MatrixMarket.jl" begin
    for t in tests
        include("$(t).jl")
    end
end
