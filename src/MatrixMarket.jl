module MatrixMarket

function mmread(filename::ASCIIString, infoonly::Bool=false)
#      Reads the contents of the Matrix Market file 'filename'
#      into a matrix, which will be either sparse or dense,
#      depending on the Matrix Market format indicated by
#      'coordinate' (coordinate sparse storage), or
#      'array' (dense array storage).  The data will be duplicated
#      as appropriate if symmetry is indicated in the header. (Not yet
#      implemented).
#
#      If infoonly is true information on the size and structure is
#      returned.
    mmfile = open(filename,"r")
    firstline = chomp(readline(mmfile))
    tokens = split(firstline)
    length(tokens)==5 || throw(ParseError(string("Not enough words on first line: ", ll)))
    tokens[1]=="%%MatrixMarket" || throw(ParseError(string("Not a valid MatrixMarket header:", ll)))
    (head1, rep, field, symm) = map(lowercase, tokens[2:5])
    head1=="matrix" || throw(ValueError("Unknown MatrixMarket data type: $head1 (only \"matrix\" is supported)"))
    field=="real" || throw(ValueError("non-float fields not yet allowed"))

    ll   = readline(mmfile)         # Read through comments, ignoring them
    while length(chomp(ll))==0 || (length(ll) > 0 && ll[1] == '%') ll = readline(mmfile) end
    dd     = int(split(ll))         # Read dimensions
    length(dd) >= (rep == "coordinate" ? 3 : 2) || throw(ParseError(string("Could not read in rows, columns, entries from line: ", ll)))
    rows   = dd[1]
    cols   = dd[2]
    entries = rep == "coordinate" ? dd[3] : rows * cols
    if infoonly return rows, cols, entries, rep, field, symm end
    if rep == "coordinate"
        rr = Array(Int, entries)
        cc = Array(Int, entries)
        xx = Array(Float64, entries)
        for i in 1:entries
            flds = split(readline(mmfile))
            rr[i] = int32(flds[1])
            cc[i] = int32(flds[2])
            xx[i] = float64(flds[3])
        end
        return sparse(rr, cc, xx, rows, cols)
    end
    reshape([float64(readline(mmfile)) for i in 1:entries], (rows,cols))
end

end # module

