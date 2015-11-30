module MatrixMarket

using HTTPClient
# using Requests
using Libz
export mmread, mmget

"""
### mmread(filename, infoonly::Bool=false)

Read the contents of the Matrix Market file 'filename' into a matrix,
which will be either sparse or dense, depending on the Matrix Market format
indicated by 'coordinate' (coordinate sparse storage), or 'array' (dense
array storage).

If infoonly is true (default: false), only information on the size and
structure is returned from reading the header. The actual data for the
matrix elements are not parsed.
"""
function mmread(filename, infoonly::Bool=false)
    retval = spzeros(0,0)
    open(filename,"r") do mmfile
        retval = _mmio(mmfile, infoonly)
    end
    return retval
end

function mmget(url::AbstractString, infoonly::Bool=false)
    compress = false
    tar = false
    seekto = 0
    response = get(url)
    if startswith(url, "ftp://") && (endswith(url,".gz") || endswith(url, ".Z"))
        compress = true
    end
    if endswith(url,".tar") || endswith(url,".tgz") || endswith(url, ".tar.gz")
        tar = true
    end
    ct = get(response.headers,"Content-Type", [])
    if "application/x-gzip" in ct
        compress = true
    end
    if tar
        seekto = 512
    end
    mmfile = response.body
    seek(mmfile,0)
    if compress
        mmfile = mmfile |> ZlibInflateInputStream

    end
    if tar
        readbytes(mmfile, seekto)   # skip the header for http
    end
    return _mmio(mmfile, infoonly)
end


# requires an open IO
function _mmio(mmfile::IO, infoonly::Bool)
    # Read first line
    firstline = chomp(readline(mmfile))
    tokens = split(firstline)
    if length(tokens) != 5
        throw(ParseError(string("Not enough words on first line: ", firstline)))
    end
    if tokens[1] != "%%MatrixMarket"
        throw(ParseError(string("Not a valid MatrixMarket header:", firstline)))
    end
    (head1, rep, field, symm) = map(lowercase, tokens[2:5])
    if head1 != "matrix"
        throw(ParseError("Unknown MatrixMarket data type: $head1 (only \"matrix\" is supported)"))
    end

    eltype = field == "real" ? Float64 :
             field == "complex" ? Complex128 :
             field == "pattern" ? Bool :
             throw(ParseError("Unsupported field $field (only real and complex are supported)"))

    symlabel = symm == "general" ? identity :
               symm == "symmetric" ? symmetric! :
               symm == "hermitian" ? hermitian! :
               symm == "skew-symmetric" ? skewsymmetric! :
               throw(ParseError("Unknown matrix symmetry: $symm (only general, symmetric, skew-symmetric and hermitian are supported)"))

    # Skip all comments and empty lines
    ll   = readline(mmfile)
    while length(chomp(ll))==0 || (length(ll) > 0 && ll[1] == '%')
        ll = readline(mmfile)
    end
    # Read matrix dimensions (and number of entries) from first non-comment line
    dd = map(x->parse(Int, x), split(ll))
    if length(dd) < (rep == "coordinate" ? 3 : 2)
        throw(ParseError(string("Could not read in matrix dimensions from line: ", ll)))
    end
    rows = dd[1]
    cols = dd[2]
    entries = (rep == "coordinate") ? dd[3] : (rows * cols)
    if infoonly
        return (rows, cols, entries, rep, field, symm)
    end
    if rep == "coordinate"
        rr = Array(Int, entries)
        cc = Array(Int, entries)
        xx = Array(eltype, entries)
        for i in 1:entries
            flds = split(readline(mmfile))
            rr[i] = parse(Int, flds[1])
            cc[i] = parse(Float64, flds[2])
            if eltype == Complex128
                xx[i] = Complex128(parse(Float64, flds[3]), parse(Float64, flds[4]))
            elseif eltype == Float64
                xx[i] = parse(Float64, flds[3])
            else
                xx[i] = true
            end
        end
        return symlabel(sparse(rr, cc, xx, rows, cols))
    end
    return symlabel(reshape([parse(Float64, readline(mmfile)) for i in 1:entries], (rows,cols)))
end

# Hack to represent skew-symmetric matrix as an ordinary matrix with duplicated elements
function skewsymmetric!(M::AbstractMatrix)
    m,n = size(M)
    m == n || throw(DimensionMismatch())
    for i=1:n, j=1:n
        if M[i,j] != 0
            M[j,i] = -M[i,j]
        end
    end
    return M
end

function symmetric!(M::AbstractMatrix)
    m,n = size(M)
    m == n || throw(DimensionMismatch())
    for i=1:n, j=1:n
        if M[i,j] != 0
            M[j,i] = M[i,j]
        end
    end
    return M
end

function hermitian!(M::AbstractMatrix)
    m,n = size(M)
    m == n || throw(DimensionMismatch())
    for i=1:n, j=1:n
        if M[i,j] != 0
            M[j,i] = conj(M[i,j])
        end
    end
    return M
end

end # module
