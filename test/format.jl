@testset "format" begin
    @testset "CoordinateFormat" begin
        T = Float64
        rows = [1, 2, 2, 3, 5, 7]
        cols = [1, 1, 2, 3, 4, 4]
        vals = T[1, 2, 3, 4, 5, 6]
        A = sparse(rows, cols, vals)

        f = MatrixMarket.CoordinateFormat(rows, cols, vals)
        @test MatrixMarket.CoordinateFormat(A) == f
        @test length(f) == length(vals)
        @test eltype(f) == T
        @test MatrixMarket.formattext(f) == "coordinate"
        @test Tuple(f) == (rows, cols, vals)
        @test MatrixMarket.readout(f, 7, 4, "general") == A

        MatrixMarket.writeat!(f, 2, "3 1 7")
        @test (f.rows[2], f.cols[2], f.vals[2]) == (3, 1, 7)
    end

    @testset "ArrayFormat" begin
        T = Float64
        vals = T[1, 2, 3, 4, 5, 6]
        A = reshape(vals, 2, 3)

        f = MatrixMarket.ArrayFormat(vals)
        @test MatrixMarket.ArrayFormat(A) == f
        @test length(f) == length(vals)
        @test eltype(f) == T
        @test MatrixMarket.formattext(f) == "array"
        @test Tuple(f) == (vals, )
        @test MatrixMarket.readout(f, 2, 3, "general") == A

        MatrixMarket.writeat!(f, 2, "7")
        @test f.vals[2] == 7
    end
end
