#############################################################
# Download and parse every file from the NIST Matrix Market #
#############################################################

#Convenience function to emulate the behavior of gunzip
using GZip
function gunzip(fname)
    endswith(fname, ".gz") || error("gunzip: $fname: unknown suffix -- ignored")
    destname = split(fname, ".gz")[1] #XXX potential bug, assumes that ".gz" doesn't happen in the middle of a filename
    open(destname, "w") do f
        GZip.open(fname) do g
            write(f, readall(g))
        end
    end
    destname
end

#Download and parse master list of matrices
isfile("matrices.html") || download("http://math.nist.gov/MatrixMarket/matrices.html", "matrices.html")
matrixmarketdata = {}
open("matrices.html") do f
   for line in readlines(f)
       if contains(line, """<A HREF="/MatrixMarket/data/""")
           collectionname, setname, matrixname = split(split(line, '"')[2], '/')[4:6]
           matrixname = split(matrixname, '.')[1]
           push!(matrixmarketdata, (collectionname, setname, matrixname) )
       end
   end
end

#Download one matrix at random
n = rand(1:length(matrixmarketdata))
for (collectionname, setname, matrixname) in matrixmarketdata[n:n]
    fn = string(collectionname, '_', setname, '_', matrixname)
    mtxfname = string(fn, ".mtx")
    if !isfile(mtxfname)
        url = "ftp://math.nist.gov/pub/MatrixMarket2/$collectionname/$setname/$matrixname.mtx.gz"
        gzfname = string(fn, ".mtx.gz")
        try
            download(url, gzfname)
        catch continue end
        gunzip(gzfname)
    end
end

