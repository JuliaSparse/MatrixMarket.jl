# A number type that fails to print, to make `mmwrite` throw after writing the header.
struct Unprintable <: AbstractFloat
    x::Float64
end
Base.show(::IO, ::Unprintable) = error("Unprintable")
Base.print(::IO, ::Unprintable) = error("Unprintable")

writegz(filename, s) = open(io -> (z = GzipCompressorStream(io); write(z, s); close(z)), filename, "w")
readgz(filename) = open(io -> read(GzipDecompressorStream(io), String), filename)

@testset "io" begin
    header = "%%MatrixMarket matrix coordinate real general\n"
    A = sparse([1, 2], [1, 3], [1.5, 2.5], 2, 3)

    mktempdir() do dir
        @testset "truncated header" begin
            for (name, s) in [
                ("header.mtx", header),
                ("header_nonl.mtx", chomp(header)),
                ("comments.mtx", header * "% comment\n%\n\n  \n"),
            ]
                filename = joinpath(dir, name)
                write(filename, s)
                @test_throws MatrixMarket.FileFormatException mminfo(filename)

                writegz(filename * ".gz", s)
                @test_throws MatrixMarket.FileFormatException mminfo(filename * ".gz")
            end
        end

        @testset "CRLF line endings" begin
            filename = joinpath(dir, "crlf.mtx")
            write(filename, "%%MatrixMarket matrix coordinate real general\r\n% c\r\n\r\n2 3 2\r\n1 1 1.5\r\n2 3 2.5\r\n")
            @test mminfo(filename) == (2, 3, 2, "coordinate", "real", "general")
        end

        @testset "wrong number of words in header" begin
            for (line, n) in [
                ("%%MatrixMarket matrix coordinate real", 4),
                ("%%MatrixMarket matrix coordinate real general extra", 6),
            ]
                e = try
                    mminfo(IOBuffer(line * "\n2 3 2\n"))
                catch e
                    e
                end
                @test e isa MatrixMarket.FileFormatException
                @test occursin("Expected 5 words", e.msg)
                @test occursin("got $n words", e.msg)
            end
        end

        @testset "SubString filenames" begin
            filename = joinpath(dir, "sub.mtx")
            subname = SubString(filename * "~", 1, lastindex(filename))
            @test subname isa SubString
            mmwrite(subname, A)
            @test isfile(filename)
            @test mminfo(subname) == (2, 3, 2, "coordinate", "real", "general")
        end

        @testset "write .gz" begin
            filename = joinpath(dir, "out.mtx")
            mmwrite(filename, A)
            mmwrite(filename * ".gz", A)
            @test readgz(filename * ".gz") == read(filename, String)
            @test mminfo(filename * ".gz") == (2, 3, 2, "coordinate", "real", "general")
        end

        @testset "failed write closes the file" begin
            # Unsupported element type fails before anything is written.
            filename = joinpath(dir, "rational.mtx")
            @test_throws ErrorException mmwrite(filename, sparse(Rational[1//2 0; 0 1]))
            @test read(filename, String) == ""
            rm(filename)
            @test !isfile(filename)

            # Failing mid-write still flushes what was written, so the stream was closed.
            B = SparseMatrixCSC(2, 3, [1, 2, 2, 2], [1], [Unprintable(1.0)])
            filename = joinpath(dir, "unprintable.mtx")
            @test_throws ErrorException mmwrite(filename, B)
            @test read(filename, String) == header * "2 3 1\n"
            rm(filename)

            # For .gz the compressor must be closed too, or the gzip trailer is missing.
            @test_throws ErrorException mmwrite(filename * ".gz", B)
            @test readgz(filename * ".gz") == header * "2 3 1\n"
            rm(filename * ".gz")
        end
    end
end
