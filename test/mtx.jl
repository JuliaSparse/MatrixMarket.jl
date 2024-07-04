@testset "mtx" begin
    mtx_filename = joinpath(TEST_PATH, "data", "test.mtx")
    res = sparse(
        [5, 4, 1, 2, 6],
        [1, 5, 1, 4, 7],
        [1, 1, 1, 1, 1],
        11, 12
    )

    testmatrices = download_unzip_nist_files()

    @testset "read/write mtx" begin
        rows, cols, entries, rep, field, symm = mminfo(mtx_filename)
        @test rows == 11
        @test cols == 12
        @test entries == 5
        @test rep == "coordinate"
        @test field == "integer"
        @test symm == "general"

        A = mmread(mtx_filename)
        @test A isa SparseMatrixCSC
        @test A == res

        newfilename = replace(mtx_filename, "test.mtx" => "test_write.mtx")
        mmwrite(newfilename, res)

        f = open(mtx_filename)
        sha_test = bytes2hex(sha256(read(f, String)))
        close(f)

        f = open(newfilename)
        sha_new = bytes2hex(sha256(read(f, String)))
        close(f)

        @test sha_test == sha_new
        rm(newfilename)
    end

    @testset "read/write mtx.gz" begin
        gz_filename = mtx_filename * ".gz"
        rows, cols, entries, rep, field, symm = mminfo(gz_filename)
        @test rows == 11
        @test cols == 12
        @test entries == 5
        @test rep == "coordinate"
        @test field == "integer"
        @test symm == "general"

        A = mmread(gz_filename)
        @test A isa SparseMatrixCSC
        @test A == res

        newfilename = replace(gz_filename, "test.mtx.gz" => "test_write.mtx.gz")
        mmwrite(newfilename, res)

        stream = GzipDecompressorStream(open(gz_filename))
        sha_test = bytes2hex(sha256(read(stream, String)))
        close(stream)

        stream = GzipDecompressorStream(open(newfilename))
        sha_new = bytes2hex(sha256(read(stream, String)))
        close(stream)

        @test sha_test == sha_new
        rm(newfilename)
    end

    @testset "read/write NIST mtx files" begin
        # verify mmread(mmwrite(A)) == A
        for filename in filter(t -> endswith(t, ".mtx"), readdir())
            new_filename = replace(filename, ".mtx" => "_.mtx")
            A = MatrixMarket.mmread(filename)

            MatrixMarket.mmwrite(new_filename, A)
            new_A = MatrixMarket.mmread(new_filename)
            @test new_A == A
            rm(new_filename)
        end
    end

    @testset "read/write NIST mtx.gz files" begin
        for gz_filename in filter(t -> endswith(t, ".mtx.gz"), readdir())
            mtx_filename = replace(gz_filename, ".mtx.gz" => ".mtx")

            # reading from .mtx and .mtx.gz must be identical
            A_gz = MatrixMarket.mmread(gz_filename)

            A = MatrixMarket.mmread(mtx_filename)
            @test A_gz == A

            # writing to .mtx and .mtx.gz must be identical
            new_filename = replace(gz_filename, ".mtx.gz" => "_.mtx.gz")
            mmwrite(new_filename, A)

            new_A = MatrixMarket.mmread(new_filename)
            @test new_A == A

            rm(new_filename)
        end
    end

    # clean up
    for filename in filter(t -> endswith(t, ".mtx"), readdir())
        rm(filename)
        rm(filename * ".gz")
    end
end
