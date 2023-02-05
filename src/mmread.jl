"""
    mmread(filename, infoonly=false, retcoord=false)

Read the contents of the Matrix Market file `filename` into a matrix, which will be either
sparse or dense, depending on the Matrix Market format indicated by `coordinate` (coordinate
sparse storage), or `array` (dense array storage).

# Arguments

- `filename::String`: The file to read.
- `infoonly::Bool=false`: Only information on the size and structure is returned from
    reading the header. The actual data for the matrix elements are not parsed.
- `retcoord::Bool`: If it is `true`, the rows, column and value vectors are returned along
    with the header information.
"""
function mmread(filename::String, infoonly::Bool=false, retcoord::Bool=false)
    stream = open(filename, "r")
    result = infoonly ? mminfo(stream) : mmread(stream, retcoord)
    close(stream)

    return result
end

function mmread(stream::IO, infoonly::Bool=false, retcoord::Bool=false)
    rows, cols, entries, rep, field, symm = mminfo(stream)

    infoonly && return rows, cols, entries, rep, field, symm

    T = parse_eltype(field)
    symfunc = parse_symmetric(symm)

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
        vals = [parse(Float64, readline(stream)) for _ in 1:entries]
        A = reshape(vals, rows, cols)
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

function parse_symmetric(symm::String)
    if symm == "general"
        return identity
    elseif symm == "symmetric" || symm == "hermitian"
        return hermitianize!
    elseif symm == "skew-symmetric"
        return skewsymmetrize!
    else
        throw(FileFormatException("Unknown matrix symmetry: $symm."))
    end
end

function hermitianize!(M::AbstractMatrix)
    M .+= tril(M, -1)'
    return M
end

function skewsymmetrize!(M::AbstractMatrix)
    M .-= tril(M, -1)'
    return M
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
