@testset "reader" begin
    reader = MatrixMarket.MMReader(7, 4, 6, "coordinate", "real", "general")
    @test reader.nrow == 7
    @test reader.ncol == 4
    @test reader.nentry == 6
    @test eltype(reader.format) == Float64
    @test reader.format isa MatrixMarket.CoordinateFormat
    @test_throws AssertionError MatrixMarket.MMReader(7, 4, 100, "coordinate", "real", "general")
    @test MatrixMarket.readout(reader, true)[4:end] == (7, 4, 6, "coordinate", "real", "general")

    reader = MatrixMarket.MMReader(2, 3, 6, "array", "integer", "general")
    @test reader.nrow == 2
    @test reader.ncol == 3
    @test reader.nentry == 6
    @test eltype(reader.format) == Int64
    @test reader.format isa MatrixMarket.ArrayFormat
    @test MatrixMarket.readout(reader, true)[2:end] == (2, 3, 6, "array", "integer", "general")

    @test_throws MatrixMarket.FileFormatException MatrixMarket.parse_eltype("aaa")
    @test_throws MatrixMarket.FileFormatException MatrixMarket.parse_symmetric("aaa")
    @test MatrixMarket.parse_dimension("3 4", "array") == (3, 4, 12)
    @test_throws MatrixMarket.FileFormatException MatrixMarket.parse_dimension("3 4", "coordinate")
end
