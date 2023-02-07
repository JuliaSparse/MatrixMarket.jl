using MatrixMarket
using CodecZlib
using Downloads
using GZip
using SparseArrays
using SHA
using Test

function download_nist_filelist()
    isfile("matrices.html") ||
        Downloads.download("math.nist.gov/MatrixMarket/matrices.html", "matrices.html")

    matrixmarketdata = Any[]
    open("matrices.html") do f
        for line in readlines(f)
            if occursin("""<A HREF="/MatrixMarket/data/""", line)
                collectionname, setname, matrixname = split(split(line, '"')[2], '/')[4:6]
                matrixname = split(matrixname, '.')[1]
                push!(matrixmarketdata, (collectionname, setname, matrixname))
            end
        end
    end
    rm("matrices.html")

    return matrixmarketdata
end

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
