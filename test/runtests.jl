#Attempts to read every .mtx file in the test directory
using MatrixMarket
using Compat.Test
using Compat

include("dl-matrixmarket.jl")

num_errors = 0
num_pass = 0

@testset "read and write $filename" for filename in filter(t -> endswith(t, ".mtx"), readdir())
    new_filename = "$(filename)_"
    A = MatrixMarket.mmread(filename)
    @info("$(typeof(A))  $(size(A))")

    # verify mmread(mmwrite(A)) == A
    MatrixMarket.mmwrite(new_filename, A)
    new_A = MatrixMarket.mmread(new_filename)
    @test new_A == A

    rm(filename)
    rm(new_filename)
end
