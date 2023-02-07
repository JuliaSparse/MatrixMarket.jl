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

function download_nist_filelist()
    isfile("matrices.html") ||
        Downloads.download("math.nist.gov/MatrixMarket/matrices.html", "matrices.html")

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
            url = "https://math.nist.gov/pub/MatrixMarket2/$collectionname/$setname/$matrixname.mtx.gz"
            gzfname = string(fn, ".mtx.gz")
            try
                Downloads.download(url, gzfname)
            catch
                continue
            end
            gunzip(gzfname)
        end
    end

    return testmatrices
end
