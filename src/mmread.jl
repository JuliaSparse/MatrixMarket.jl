"""
    mmread(filename, infoonly=false, retcoord=false)

Read the contents of the Matrix Market file `filename` into a matrix, which will be either
sparse or dense, depending on the Matrix Market format indicated by `coordinate` (coordinate
sparse storage), or `array` (dense array storage).

Files whose name ends in `.gz` are decompressed. Matrices with `symmetric`, `hermitian` or
`skew-symmetric` symmetry are expanded from the stored lower triangle. Dense arrays are read
as `Matrix{Float64}` (`real` and `integer` fields) or `Matrix{ComplexF64}` (`complex` field).

# Arguments

- `filename::AbstractString`: The file to read. An `IO` stream can be passed instead.
- `infoonly::Bool=false`: Only information on the size and structure is returned from
    reading the header. The actual data for the matrix elements are not parsed.
- `retcoord::Bool=false`: If it is `true`, the rows, column and value vectors are returned
    along with the header information for `coordinate` files, as
    `(rows, cols, vals, nrows, ncols, entries, rep, field, symm)`. Symmetry is not expanded.
"""
function mmread(filename::AbstractString, infoonly::Bool=false, retcoord::Bool=false)
    return open_mm(stream -> mmread(stream, infoonly, retcoord), filename)
end

function mmread(stream::IO, infoonly::Bool=false, retcoord::Bool=false)
    rows, cols, entries, rep, field, symm = mminfo(stream)

    infoonly && return rows, cols, entries, rep, field, symm

    T = parse_eltype(field)
    symfunc = parse_symmetric(symm)

    if symm != "general" && rows != cols
        throw(FileFormatException("A $symm matrix must be square, got $rows×$cols."))
    end

    if rep == "coordinate"
        rn = Vector{Int}(undef, entries)
        cn = Vector{Int}(undef, entries)
        vals = Vector{T}(undef, entries)
        for i in 1:entries
            line = readline(stream)
            splits = find_splits(line, num_splits(T))
            rn[i] = parse_row(line, splits)
            cn[i] = parse_col(line, splits, T)
            vals[i] = parse_val(line, splits, T)
        end

        result = retcoord ? (rn, cn, vals, rows, cols, entries, rep, field, symm) :
                            symfunc(sparse(rn, cn, vals, rows, cols))
    else
        A = read_array(stream, array_eltype(field), rows, cols, symm)
        result = symfunc(A)
    end

    return result
end

function parse_eltype(field::String)
    if field == "real"
        return Float64
    elseif field == "complex"
        return ComplexF64
    elseif field == "integer"
        return Int64
    elseif field == "pattern"
        return Bool
    else
        throw(FileFormatException("Unsupported field $field."))
    end
end

# Dense arrays keep reading integers as Float64.
function array_eltype(field::String)
    if field == "real" || field == "integer"
        return Float64
    elseif field == "complex"
        return ComplexF64
    else
        throw(FileFormatException("Field $field is not supported for array format."))
    end
end

function parse_symmetric(symm::String)
    if symm == "general"
        return identity
    elseif symm == "symmetric"
        return symmetrize!
    elseif symm == "hermitian"
        return hermitianize!
    elseif symm == "skew-symmetric"
        return skewsymmetrize!
    else
        throw(FileFormatException("Unknown matrix symmetry: $symm."))
    end
end

# In-place broadcasting preserves the element type, e.g. `Bool` for pattern matrices.
function symmetrize!(M::AbstractMatrix)
    M .+= transpose(tril(M, -1))
    return M
end

function hermitianize!(M::AbstractMatrix)
    M .+= adjoint(tril(M, -1))
    return M
end

function skewsymmetrize!(M::AbstractMatrix)
    M .-= transpose(tril(M, -1))
    return M
end

# Read the column-major values of a dense array. Symmetric and Hermitian arrays store the lower
# triangle including the diagonal, skew-symmetric arrays the strictly lower triangle.
function read_array(stream::IO, ::Type{T}, rows, cols, symm) where {T}
    A = zeros(T, rows, cols)
    for j in 1:cols
        first_row = symm == "general" ? 1 : symm == "skew-symmetric" ? j + 1 : j
        for i in first_row:rows
            A[i, j] = parse_array_val(readline(stream), T)
        end
    end
    return A
end

function parse_array_val(line, ::Type{T}) where {T}
    tokens = split(line)
    n = T <: Complex ? 2 : 1
    length(tokens) == n ||
        throw(FileFormatException("Expected $n value(s) on array line, got: $(repr(line))"))
    return n == 2 ? T(parse(Float64, tokens[1]), parse(Float64, tokens[2])) : parse(T, tokens[1])
end

parse_row(line, splits) = parse(Int, line[1:splits[1]])

parse_col(line, splits, ::Type{Bool}) = parse(Int, line[splits[1]:end])
parse_col(line, splits, eltype) = parse(Int, line[splits[1]:splits[2]])

function parse_val(line, splits, ::Type{ComplexF64})
    real = parse(Float64, line[splits[2]:splits[3]])
    imag = parse(Float64, line[splits[3]:length(line)])
    return ComplexF64(real, imag)
end

parse_val(line, splits, ::Type{Bool}) = true
parse_val(line, splits, ::Type{T}) where {T} = parse(T, line[splits[2]:length(line)])

num_splits(::Type{ComplexF64}) = 3
num_splits(::Type{Bool}) = 1
num_splits(elty) = 2

function find_splits(s::String, num)
    splits = Vector{Int}(undef, num)
    cur = 1
    in_space = s[1] == '\t' || s[1] == ' '
    @inbounds for i in 1:length(s)
        if s[i] == '\t' || s[i] == ' '
            if !in_space
                in_space = true
                splits[cur] = i
                cur += 1
                cur > num && break
            end
        else
            in_space = false
        end
    end

    splits
end
