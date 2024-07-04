module MatrixMarket

using SparseArrays
using LinearAlgebra

using CodecZlib

export mmread, mmwrite, mminfo

include("mminfo.jl")
include("mmread.jl")
include("mmwrite.jl")

end # module
