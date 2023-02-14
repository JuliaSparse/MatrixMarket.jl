@testset "writer" begin
    A = sparse(rand([0, 1], 3, 4))
    writer = MatrixMarket.MMWriter(A)
    @test writer.nrow == size(A, 1)
    @test writer.ncol == size(A, 2)
    @test writer.nentry == nnz(A)
    @test writer.symm == "general"
    @test eltype(writer.format) == Int64
    @test writer.format isa MatrixMarket.CoordinateFormat
    @test MatrixMarket.header(writer) == "%%MatrixMarket matrix coordinate integer general"
    @test MatrixMarket.sizetext(writer) == "$(size(A, 1)) $(size(A, 2)) $(nnz(A))"

    A = rand(ComplexF64, 3, 4)
    writer = MatrixMarket.MMWriter(A)
    @test writer.nrow == size(A, 1)
    @test writer.ncol == size(A, 2)
    @test writer.nentry == length(A)
    @test writer.symm == "general"
    @test eltype(writer.format) == ComplexF64
    @test writer.format isa MatrixMarket.ArrayFormat
    @test MatrixMarket.header(writer) == "%%MatrixMarket matrix array complex general"
    @test MatrixMarket.sizetext(writer) == "$(size(A, 1)) $(size(A, 2)) $(length(A))"
end
