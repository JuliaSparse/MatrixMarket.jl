module MatrixMarket

export mmread, mmwrite

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
    mmfile = open(filename,"r")
    # Read first line
    firstline = chomp(readline(mmfile))
    tokens = split(firstline)
    if length(tokens) != 5
        throw(ParseError(string("Not enough words on first line: ", ll)))
    end
    if tokens[1] != "%%MatrixMarket"
        throw(ParseError(string("Not a valid MatrixMarket header:", ll)))
    end
    (head1, rep, field, symm) = map(lowercase, tokens[2:5])
    if head1 != "matrix"
        throw(ParseError("Unknown MatrixMarket data type: $head1 (only \"matrix\" is supported)"))
    end

    eltype = field == "real" ? Float64 :
             field == "complex" ? Complex128 :
             field == "integer" ? Int64 :
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
            line = readline(mmfile)

            num_splits = if eltype == Complex128
                             3
                         elseif eltype == Bool
                             1
                         else
                             2
                         end
            splits = find_splits(line, num_splits)

            rr[i] = parse(Int, line[1:splits[1]])
            if eltype == Bool
                cc[i] = parse(Int, line[splits[1]:end])
            else
                cc[i] = parse(Int, line[splits[1]:splits[2]])
            end

            if eltype == Complex128
                real = parse(Float64, line[splits[2]:splits[3]])
                imag = parse(Float64, line[splits[3]:length(line)])
                xx[i] = Complex128(real, imag)
            elseif eltype == Bool
                xx[i] = true
            else
                xx[i] = parse(eltype, line[splits[2]:length(line)])
            end
        end
        return symlabel(sparse(rr, cc, xx, rows, cols))
    end
    return symlabel(reshape([parse(Float64, readline(mmfile)) for i in 1:entries], (rows,cols)))
end

function find_splits(s :: String, num)
    splits = Array(Int, num)
    cur = 1
    in_space = s[1] == '\t' || s[1] == ' '
    @inbounds for i in 1:length(s)
        if s[i] == '\t' || s[i] == ' '
            if !in_space
                in_space = true
                splits[cur] = i
                cur += 1
                if cur > num
                    break;
                end
            end
        else
            in_space = false
        end
    end

    splits
end

# Hack to represent skew-symmetric matrix as an ordinary matrix with duplicated elements
function skewsymmetric!(M::AbstractMatrix)
    m,n = size(M)
    m == n || throw(DimensionMismatch())
    return M - transpose(tril(M, -11))
end

function symmetric!(M::AbstractMatrix)
    m,n = size(M)
    m == n || throw(DimensionMismatch())
    if eltype(M) == Bool
        return M | transpose(tril(M, -1))
    else
        return M + transpose(tril(M, -1))
    end
end

function hermitian!(M::AbstractMatrix)
    m,n = size(M)
    m == n || throw(DimensionMismatch())
    if eltype(M) == Bool
        return M | conj(transpose(tril(M, -1)))
    else
        return M + conj(transpose(tril(M, -1)))
    end
end

"""
### mmwrite(filename, matrix::SparseMatrixCSC)

Write a sparse matrix to file 'filename'.
"""
function mmwrite(filename, matrix :: SparseMatrixCSC)
  open(filename, "w") do file
    elem = eltype(matrix) <: Bool ? "pattern" :
           eltype(matrix) <: Integer ?  "integer" :
           eltype(matrix) <: AbstractFloat ? "real" :
           eltype(matrix) <: Complex ? "complex" :
           error("Invalid matrix type")
      sym = ishermitian(matrix) ? "hermitian" :
            issymmetric(matrix) ? "symmetric" :
            "general"
      symb = issymmetric(matrix)

      # write mm header
      write(file, "%%MatrixMarket matrix coordinate $elem $sym\n")

      # write matrix size and number of nonzeros
      diagnnz = length(filter(x -> x != 0, diag(matrix)))
      numnz = symb ? div(nnz(matrix) - diagnnz, 2) + diagnnz :
              nnz(matrix)
      write(file, "$(size(matrix, 1)) $(size(matrix, 2)) $numnz\n")

      rows = rowvals(matrix)
      vals = nonzeros(matrix)
      for i in 1:size(matrix, 1)
          for j in nzrange(matrix, i)
              if !symb || rows[j] >= i
                  write(file, "$(rows[j]) $i")
                    if elem == "pattern" # omit values on pattern matrices
                    elseif elem == "complex"
                        write(file, " $(real(vals[j])) $(imag(vals[j]))")
                    else
                        write(file, " $(vals[j])")
                    end
                  write(file, "\n")
              end
          end
      end
  end
end

end # module
