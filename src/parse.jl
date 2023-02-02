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

function parse_dimension(line::String, rep::String)
    dims = map(x -> parse(Int, x), split(line))

    if length(dims) < (rep == "coordinate" ? 3 : 2)
        throw(FileFormatException(string("Could not read in matrix dimensions from line: ", line)))
    end

    if rep == "coordinate"
        return dims[1], dims[2], dims[3]
    else
        return dims[1], dims[2], (dims[1] * dims[2])
    end
end

function parseline(::Type{T}, line) where T
    splits = find_splits(line, num_splits(T))
    r = parse_row(line, splits)
    c = parse_col(line, splits, T)
    v = parse_val(line, splits, T)
    return r, c, v
end

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
