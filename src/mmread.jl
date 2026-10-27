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

    # Read the data section at once and parse it in place, instead of allocating a line per entry.
    data = DataReader(String(read(stream)), 1)

    if rep == "coordinate"
        rn = Vector{Int}(undef, entries)
        cn = Vector{Int}(undef, entries)
        vals = Vector{T}(undef, entries)
        read_coordinates!(data, rn, cn, vals)

        result = retcoord ? (rn, cn, vals, rows, cols, entries, rep, field, symm) :
                            symfunc(sparse(rn, cn, vals, rows, cols))
    else
        A = read_array(data, array_eltype(field), rows, cols, symm)
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

# A separate function so the loop is compiled for the concrete element type `T`.
function read_coordinates!(data, rn, cn, vals::Vector{T}) where {T}
    for i in eachindex(rn, cn, vals)
        rn[i] = read_int(data, true)
        cn[i] = read_int(data, false)
        vals[i] = read_val(data, T)
        end_line!(data)
    end
    return rn, cn, vals
end

# Read the column-major values of a dense array. Symmetric and Hermitian arrays store the lower
# triangle including the diagonal, skew-symmetric arrays the strictly lower triangle.
function read_array(data, ::Type{T}, rows, cols, symm) where {T}
    A = zeros(T, rows, cols)
    for j in 1:cols
        first_row = symm == "general" ? 1 : symm == "skew-symmetric" ? j + 1 : j
        for i in first_row:rows
            A[i, j] = T <: Complex ? read_val(data, T, true) : read_float(data, true)
            end_line!(data)
        end
    end
    return A
end

# Cursor over the data section of a file. Each entry is on its own line: its first token may
# follow blank lines, the rest must be on the same line.
mutable struct DataReader
    s::String
    pos::Int
end

isblank(c::UInt8) = c == UInt8(' ') || c == UInt8('\t') || c == UInt8('\r')

# Return the byte range of the next token.
function next_token(data::DataReader, first::Bool)
    s, n, i = data.s, ncodeunits(data.s), data.pos
    @inbounds while i <= n
        c = codeunit(s, i)
        if c == UInt8('\n')
            first || break
        elseif !isblank(c)
            break
        end
        i += 1
    end
    if i > n || codeunit(s, i) == UInt8('\n')
        throw(FileFormatException(first ? "Unexpected end of file: fewer entries than declared" :
                                          "Missing value on line: $(repr(current_line(data)))"))
    end
    j = i
    @inbounds while j <= n && !isblank(codeunit(s, j)) && codeunit(s, j) != UInt8('\n')
        j += 1
    end
    data.pos = j
    return i, j - 1
end

# Skip to the start of the next line, which must contain only whitespace before it.
function end_line!(data::DataReader)
    s, n, i = data.s, ncodeunits(data.s), data.pos
    @inbounds while i <= n && isblank(codeunit(s, i))
        i += 1
    end
    if i <= n && codeunit(s, i) != UInt8('\n')
        throw(FileFormatException("Too many values on line: $(repr(current_line(data)))"))
    end
    data.pos = i + 1
    return data
end

function current_line(data::DataReader)
    s, p = data.s, min(data.pos, ncodeunits(data.s))
    a = something(findprev(==(UInt8('\n')), codeunits(s), p - 1), 0) + 1
    b = something(findnext(==(UInt8('\n')), codeunits(s), p), ncodeunits(s) + 1) - 1
    return SubString(s, a, b)
end

invalid_number(s, a, b) = FileFormatException("Invalid number: $(repr(SubString(s, a, b)))")

function read_int(data::DataReader, first::Bool)
    a, b = next_token(data, first)
    s = data.s
    # Plain decimal digits are by far the common case; anything else falls back to `tryparse`.
    if b - a < 18
        v = 0
        @inbounds for k in a:b
            d = codeunit(s, k) - UInt8('0')
            d > 9 && @goto fallback
            v = 10v + d
        end
        return v
    end
    @label fallback
    v = tryparse(Int, SubString(s, a, b))
    v === nothing && throw(invalid_number(s, a, b))
    return v
end

function read_float(data::DataReader, first::Bool)
    a, b = next_token(data, first)
    # Base's parser is correctly rounded and does not copy the `SubString`.
    v = tryparse(Float64, SubString(data.s, a, b))
    v === nothing && throw(invalid_number(data.s, a, b))
    return v
end

read_val(data, ::Type{Bool}) = true
read_val(data, ::Type{Int64}) = read_int(data, false)
read_val(data, ::Type{Float64}) = read_float(data, false)
read_val(data, ::Type{ComplexF64}, first::Bool=false) =
    ComplexF64(read_float(data, first), read_float(data, false))
