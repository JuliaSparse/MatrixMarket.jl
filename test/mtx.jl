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

    function gunzip(fname)
        destname, ext = splitext(fname)
        if ext != ".gz"
            error("gunzip: $fname: unknown suffix -- ignored")
        end
        open(destname, "w") do f
            GZip.open(fname) do g
                write(f, read(g, String))
            end
        end
        destname
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

    @testset "read/write NIST mtx files" begin
        # Download one matrix at random plus some specifically chosen ones.
        n = rand(1:length(NIST_FILELIST))
        testmatrices = [
            ("NEP", "mhd", "mhd1280b"),
            ("Harwell-Boeing", "acoust", "young4c"),
            ("Harwell-Boeing", "platz", "plsk1919"),
            NIST_FILELIST[n]
            ]
        for (collectionname, setname, matrixname) in testmatrices
            fn = string(collectionname, '_', setname, '_', matrixname)
            mtxfname = string(fn, ".mtx")
            if !isfile(mtxfname)
                url = "ftp://math.nist.gov/pub/MatrixMarket2/$collectionname/$setname/$matrixname.mtx.gz"
                gzfname = string(fn, ".mtx.gz")
                try
                    Downloads.download(url, gzfname)
                catch
                    continue
                end
                gunzip(gzfname)
                rm(gzfname)
            end
        end

        # verify mmread(mmwrite(A)) == A
        for filename in filter(t -> endswith(t, ".mtx"), readdir())
            new_filename = "$(filename)_"
            A = MatrixMarket.mmread(filename)

            MatrixMarket.mmwrite(new_filename, A)
            new_A = MatrixMarket.mmread(new_filename)
            @test new_A == A

            rm(filename)
            rm(new_filename)
        end
    end
end
