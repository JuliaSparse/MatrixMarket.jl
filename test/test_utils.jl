function gunzip(fname)
    destname, ext = splitext(fname)
    if ext != ".gz"
        error("gunzip: $fname: unknown suffix -- ignored")
    end
    write(destname, transcode(GzipDecompressor, read(fname)))
    destname
end

function download_nist_filelist()
    try
        isfile("matrices.html") ||
            Downloads.download("https://math.nist.gov/MatrixMarket/matrices.html", "matrices.html")
    catch e
        @warn "Could not download the NIST file list" exception=e
        return Any[]
    end

    matrixmarketdata = Any[]
    open("matrices.html") do f
        for line in readlines(f)
            if occursin("""<A HREF="/MatrixMarket/data/""", line)
                collectionname, setname, matrixname = split(split(line, '"')[2], '/')[4:6]
                matrixname = split(matrixname, '.')[1]
                push!(matrixmarketdata, (collectionname, setname, matrixname))
            end
        end
    end
    rm("matrices.html")

    return matrixmarketdata
end

function download_unzip_nist_files()
    if isempty(NIST_FILELIST)
        @warn "NIST file list unavailable, skipping NIST matrix tests"
        return Any[]
    end

    # Download one matrix at random plus some specifically chosen ones.
    # Set MATRIXMARKET_TEST_MATRIX="collection/set/name" to choose the random one.
    pick = get(ENV, "MATRIXMARKET_TEST_MATRIX", "")
    if isempty(pick)
        randmatrix = rand(NIST_FILELIST)
    else
        parts = split(pick, '/')
        length(parts) == 3 || error("MATRIXMARKET_TEST_MATRIX must be \"collection/set/name\", got \"$pick\"")
        randmatrix = Tuple(parts)
    end
    @info "Random NIST test matrix: MATRIXMARKET_TEST_MATRIX=\"$(join(randmatrix, '/'))\""

    testmatrices = [
        ("NEP", "mhd", "mhd1280b"),
        ("Harwell-Boeing", "acoust", "young4c"),
        ("Harwell-Boeing", "platz", "plsk1919"),
        randmatrix
        ]
    for (collectionname, setname, matrixname) in testmatrices
        fn = string(collectionname, '_', setname, '_', matrixname)
        mtxfname = string(fn, ".mtx")
        if !isfile(mtxfname)
            url = "https://math.nist.gov/pub/MatrixMarket2/$collectionname/$setname/$matrixname.mtx.gz"
            gzfname = string(fn, ".mtx.gz")
            try
                Downloads.download(url, gzfname)
            catch e
                @warn "Could not download $url" exception=e
                continue
            end
            gunzip(gzfname)
        end
    end

    return testmatrices
end
