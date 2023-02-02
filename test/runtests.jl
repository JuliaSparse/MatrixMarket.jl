using MatrixMarket
using CodecZlib, TranscodingStreams
using Downloads
using GZip
using SparseArrays
using SHA
using Test

const TEST_PATH = @__DIR__

tests = [
    "mtx",
    "download",
]

@testset "MatrixMarket.jl" begin
    for t in tests
        include("$(t).jl")
    end
end
