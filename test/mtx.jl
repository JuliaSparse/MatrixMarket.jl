@testset "mtx" begin
    mtx_filename = joinpath(TEST_PATH, "data", "test.mtx")
    res = sparse(
        [5, 4, 1, 2, 6],
        [1, 5, 1, 4, 7],
        [1, 1, 1, 1, 1],
        11, 12
    )

    function get_newline()
        if Sys.iswindows()
            return "\r\n"
        else
            return "\n"
        end
    end

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
end
