using MatrixMarket
using CodecZlib
using Downloads
using GZip
using SparseArrays
using SHA
using Test

include("test_utils.jl")

const TEST_PATH = @__DIR__
const NIST_FILELIST = download_nist_filelist()

tests = [
    "mtx",
]

@testset "MatrixMarket.jl" begin
    for t in tests
        include("$(t).jl")
    end
end
