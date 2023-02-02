@testset "download" begin
    # Download and parse master list of matrices
    if !isfile("matrices.html")
        Downloads.download("math.nist.gov/MatrixMarket/matrices.html", "matrices.html")
    end

    mmdata = Any[]
    open("matrices.html") do f
    for line in readlines(f)
        if occursin("""<A HREF="/MatrixMarket/data/""", line)
            collectionname, setname, matrixname = split(split(line, '"')[2], '/')[4:6]
            matrixname = split(matrixname, '.')[1]
            push!(mmdata, (collectionname, setname, matrixname) )
        end
    end
    end
    rm("matrices.html") # clean up


    # Download one matrix at random plus some specifically chosen ones.
    n = rand(1:length(mmdata))
    testmatrices = [("NEP", "mhd", "mhd1280b"),
                    ("Harwell-Boeing", "acoust", "young4c"),
                    ("Harwell-Boeing", "platz", "plsk1919"),
                    mmdata[n],
                    ]
    for (collectionname, setname, matrixname) in testmatrices
        url = "https://math.nist.gov/pub/MatrixMarket2/$collectionname/$setname/$matrixname.mtx.gz"
        buffer = PipeBuffer()
        stream = TranscodingStream(GzipDecompressor(), buffer)
        Downloads.download(url, buffer)
        mat = mmread(stream)
        @test mat isa SparseMatrixCSC
    end
end
