module MatrixMarket

function mmread(filename::String, infoonly::Bool=false)
#   Reads the contents of the Matrix Market file 'filename' into a matrix,
#   which will be either sparse or dense, depending on the Matrix Market format
#   indicated by 'coordinate' (coordinate sparse storage), or 'array' (dense
#   array storage).
#
#   If infoonly is true (default: false), only information on the size and
#   structure is returned from reading the header. The actual data for the
#   matrix elements are not parsed.
    mmfile = open(filename,"r")

    #Read first line
    firstline = chomp(readline(mmfile))
    tokens = split(firstline)
    length(tokens)==5 || throw(ParseError(string("Not enough words on first line: ", ll)))
    tokens[1]=="%%MatrixMarket" || throw(ParseError(string("Not a valid MatrixMarket header:", ll)))
    (head1, rep, field, symm) = map(lowercase, tokens[2:5])
    head1=="matrix" || throw(ValueError("Unknown MatrixMarket data type: $head1 (only \"matrix\" is supported)"))
    eltype = field=="real"    ? Float64 :
             field=="complex" ? Complex128 :
             throw(ValueError("Unsupported field $field (only real and complex are supported)"))
    symlabel = symm=="general" ? identity :
               symm=="symmetric" ? Symmetric :
               symm=="hermitian" ? Hermitian :
               symm=="skew-symmetric" ? skewsymmetric! :
               throw(ValueError("Unknown matrix symmetry: $symm (only general, symmetric, skew-symmetric and hermitian are supported)"))

    #Skip all comments and empty lines
    ll   = readline(mmfile)
    while length(chomp(ll))==0 || (length(ll) > 0 && ll[1] == '%') ll = readline(mmfile) end

    #Read matrix dimensions (and number of entries) from first non-comment line
    dd     = int(split(ll))
    length(dd) >= (rep == "coordinate" ? 3 : 2) || throw(ParseError(string("Could not read in matrix dimensions from line: ", ll)))
    rows   = dd[1]
    cols   = dd[2]
    entries = rep == "coordinate" ? dd[3] : rows * cols
    if infoonly return rows, cols, entries, rep, field, symm end
    if rep == "coordinate"
        rr = Array(Int, entries)
        cc = Array(Int, entries)
        xx = Array(eltype, entries)
        for i in 1:entries
            flds = split(readline(mmfile))
            rr[i] = int32(flds[1])
            cc[i] = int32(flds[2])
            xx[i] = eltype==Complex128 ? Complex128(float64(flds[3]), float64(flds[4])) :
                    float64(flds[3])
        end
        return symlabel(sparse(rr, cc, xx, rows, cols))
    end
    symlabel(reshape([float64(readline(mmfile)) for i in 1:entries], (rows,cols)))
end

#Hack to represent skew-symmetric matrix as an ordinary matrix with duplicated elements
function skewsymmetric!(M::AbstractMatrix)
    for i = 1:size(M,1), j = 1:size(M,2)
         M[i,j]==0 || (M[j,i] = -M[i,j])
    end
    M
end

end # module
