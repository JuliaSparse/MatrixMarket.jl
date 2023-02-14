@testset "reader" begin
    reader = MatrixMarket.MMReader(7, 4, 6, "coordinate", "real", "general")
    @test reader.nrow == 7
    @test reader.ncol == 4
    @test reader.nentry == 6
    @test eltype(reader.format) == Float64
    @test reader.format isa MatrixMarket.CoordinateFormat
    @test_throws AssertionError MatrixMarket.MMReader(7, 4, 100, "coordinate", "real", "general")

    reader = MatrixMarket.MMReader(2, 3, 6, "array", "integer", "general")
    @test reader.nrow == 2
    @test reader.ncol == 3
    @test reader.nentry == 6
    @test eltype(reader.format) == Int64
    @test reader.format isa MatrixMarket.ArrayFormat
end
