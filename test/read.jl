@testset "read" begin
    readstr(s) = mmread(IOBuffer(s))

    dir = mktempdir()
    function writefile(name, contents)
        path = joinpath(dir, name)
        write(path, contents)
        return path
    end

    coord = "%%MatrixMarket matrix coordinate real general\n2 3 2\n1 1 1.5\n2 3 -2\n"

    @testset "retcoord by filename" begin
        path = writefile("coord.mtx", coord)
        rn, cn, vals, rows, cols, entries, rep, field, symm = mmread(path, false, true)
        @test rn == [1, 2]
        @test cn == [1, 3]
        @test vals == [1.5, -2.0]
        @test (rows, cols, entries, rep, field, symm) == (2, 3, 2, "coordinate", "real", "general")
        @test mmread(path, false, true) == mmread(IOBuffer(coord), false, true)
        @test mmread(path, true) == (2, 3, 2, "coordinate", "real", "general")
        @test mmread(path) == sparse([1, 2], [1, 3], [1.5, -2.0], 2, 3)
    end

    @testset "AbstractString filename" begin
        path = writefile("coord_sub.mtx", coord)
        @test mmread(SubString(path, 1)) == mmread(path)
        @test mmread(SubString(path, 1), true) == mminfo(path)
    end

    @testset "gz by filename" begin
        path = joinpath(dir, "coord.mtx.gz")
        open(path, "w") do io
            stream = GzipCompressorStream(io)
            write(stream, coord)
            close(stream)
        end
        @test mmread(path) == sparse([1, 2], [1, 3], [1.5, -2.0], 2, 3)
        @test mmread(path, false, true)[1:3] == ([1, 2], [1, 3], [1.5, -2.0])
    end

    @testset "parse error propagates" begin
        path = writefile("bad.mtx", "%%MatrixMarket matrix coordinate real general\n2 2 1\n1 1 x\n")
        @test_throws ArgumentError mmread(path)
    end

    @testset "complex symmetric" begin
        A = readstr("%%MatrixMarket matrix coordinate complex symmetric\n2 2 2\n1 1 1 0\n2 1 0 1\n")
        @test A isa SparseMatrixCSC{ComplexF64}
        @test A == [1 im; im 0]

        A = sparse(ComplexF64[1+im 2-im 0; 2-im 0 3im; 0 3im 4])
        path = joinpath(dir, "csym.mtx")
        mmwrite(path, A)
        @test startswith(readline(path), "%%MatrixMarket matrix coordinate complex symmetric")
        @test mmread(path) == A
    end

    @testset "hermitian" begin
        A = readstr("%%MatrixMarket matrix coordinate complex hermitian\n2 2 2\n1 1 1 0\n2 1 0 1\n")
        @test A == [1 -im; im 0]

        A = sparse(ComplexF64[1 2-im 0; 2+im 0 3im; 0 -3im 4])
        path = joinpath(dir, "herm.mtx")
        mmwrite(path, A)
        @test startswith(readline(path), "%%MatrixMarket matrix coordinate complex hermitian")
        @test mmread(path) == A
    end

    @testset "skew-symmetric" begin
        A = readstr("%%MatrixMarket matrix coordinate real skew-symmetric\n3 3 2\n2 1 1.5\n3 2 2\n")
        @test A == [0 -1.5 0; 1.5 0 -2; 0 2 0]

        A = readstr("%%MatrixMarket matrix coordinate complex skew-symmetric\n2 2 1\n2 1 1 2\n")
        @test A == [0 -(1 + 2im); 1 + 2im 0]
    end

    @testset "pattern symmetric eltype" begin
        A = readstr("%%MatrixMarket matrix coordinate pattern symmetric\n3 3 3\n1 1\n2 1\n3 2\n")
        @test A isa SparseMatrixCSC{Bool}
        @test A == Bool[1 1 0; 1 0 1; 0 1 0]
    end

    @testset "integer symmetric eltype" begin
        A = readstr("%%MatrixMarket matrix coordinate integer symmetric\n2 2 2\n1 1 1\n2 1 2\n")
        @test A isa SparseMatrixCSC{Int64}
        @test A == [1 2; 2 0]
    end

    @testset "dense general" begin
        A = readstr("%%MatrixMarket matrix array real general\n2 2\n1\n2\n3\n4\n")
        @test A isa Matrix{Float64}
        @test A == [1 3; 2 4]
    end

    @testset "dense symmetric" begin
        A = readstr("%%MatrixMarket matrix array real symmetric\n2 2\n1\n2\n3\n")
        @test A isa Matrix{Float64}
        @test A == [1 2; 2 3]

        A = readstr("%%MatrixMarket matrix array real symmetric\n3 3\n1\n2\n3\n4\n5\n6\n")
        @test A == [1 2 3; 2 4 5; 3 5 6]

        A = readstr("%%MatrixMarket matrix array complex symmetric\n2 2\n1 0\n0 1\n3 0\n")
        @test A isa Matrix{ComplexF64}
        @test A == [1 im; im 3]
    end

    @testset "dense hermitian" begin
        A = readstr("%%MatrixMarket matrix array complex hermitian\n2 2\n1 0\n2 1\n3 0\n")
        @test A == [1 2-im; 2+im 3]
    end

    @testset "dense skew-symmetric" begin
        A = readstr("%%MatrixMarket matrix array real skew-symmetric\n3 3\n1\n2\n3\n")
        @test A == [0 -1 -2; 1 0 -3; 2 3 0]

        A = readstr("%%MatrixMarket matrix array complex skew-symmetric\n2 2\n1 2\n")
        @test A == [0 -(1 + 2im); 1 + 2im 0]
    end

    @testset "dense complex" begin
        A = readstr("%%MatrixMarket matrix array complex general\n1 2\n1 2\n3 4\n")
        @test A isa Matrix{ComplexF64}
        @test A == ComplexF64[1+2im 3+4im]
    end

    @testset "dense integer stays Float64" begin
        A = readstr("%%MatrixMarket matrix array integer general\n2 1\n1\n2\n")
        @test A isa Matrix{Float64}
        @test A == reshape([1.0, 2.0], 2, 1)
    end

    @testset "dense pattern is invalid" begin
        @test_throws MatrixMarket.FileFormatException readstr("%%MatrixMarket matrix array pattern general\n1 1\n1\n")
    end

    @testset "dense whitespace and CRLF" begin
        A = readstr("%%MatrixMarket matrix array real general\r\n2 1\r\n  1.5 \r\n\t2\r\n")
        @test A == reshape([1.5, 2.0], 2, 1)

        A = readstr("%%MatrixMarket matrix array complex general\r\n1 1\r\n  1.5\t -2 \r\n")
        @test A == fill(1.5 - 2im, 1, 1)
    end

    @testset "dense truncated" begin
        @test_throws MatrixMarket.FileFormatException readstr("%%MatrixMarket matrix array real general\n2 2\n1\n2\n")
        @test_throws MatrixMarket.FileFormatException readstr("%%MatrixMarket matrix array complex general\n1 1\n1\n")
    end

    @testset "non-square symmetric" begin
        @test_throws MatrixMarket.FileFormatException readstr("%%MatrixMarket matrix array real symmetric\n2 3\n1\n2\n3\n")
    end
end
