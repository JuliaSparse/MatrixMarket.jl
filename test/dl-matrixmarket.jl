#############################################################
# Download and parse every file from the NIST Matrix Market #
#############################################################

#Convenience function to emulate the behavior of gunzip
using GZip

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

#Download and parse master list of matrices
if !isfile("matrices.html")
    download("math.nist.gov/MatrixMarket/matrices.html", "matrices.html")
end

matrixmarketdata = Any[]
open("matrices.html") do f
   for line in readlines(f)
       if occursin("""<A HREF="/MatrixMarket/data/""", line)
           collectionname, setname, matrixname = split(split(line, '"')[2], '/')[4:6]
           matrixname = split(matrixname, '.')[1]
           push!(matrixmarketdata, (collectionname, setname, matrixname) )
       end
   end
end
rm("matrices.html") # clean up


#Download one matrix at random plus some specifically chosen ones.
n = rand(1:length(matrixmarketdata))
testmatrices = [ ("NEP", "mhd", "mhd1280b")
               , ("Harwell-Boeing", "acoust", "young4c")
               , ("Harwell-Boeing", "platz", "plsk1919")
               , matrixmarketdata[n]
               ]
for (collectionname, setname, matrixname) in testmatrices
    fn = string(collectionname, '_', setname, '_', matrixname)
    mtxfname = string(fn, ".mtx")
    if !isfile(mtxfname)
        url = "ftp://math.nist.gov/pub/MatrixMarket2/$collectionname/$setname/$matrixname.mtx.gz"
        gzfname = string(fn, ".mtx.gz")
        try
            download(url, gzfname)
        catch
            continue
        end
        gunzip(gzfname)
        rm(gzfname)
    end
end

