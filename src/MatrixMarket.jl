module MatrixMarket

using SparseArrays
using LinearAlgebra

export mmread, mmwrite, readinfo

struct FileFormatException <: Exception
    msg::String
end

Base.showerror(io::IO, e::FileFormatException) = print(io, e.msg)

function get_newline()
    if Sys.iswindows()
        return "\r\n"
    else
        return "\n"
    end
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

"""
    readinfo(file)

Read header information on the size and structure from file. The actual data matrix is not
parsed.

# Arguments

- `file`: The filename or io stream.
"""
function readinfo(filename::String)
    mmfile = open(filename, "r")
    info = readinfo(mmfile)
    close(mmfile)
    return info
end

function readinfo(stream::IO)
    firstline = chomp(readline(stream))
    if !startswith(firstline, "%%MatrixMarket")
        throw(FileFormatException("Expected start of header `%%MatrixMarket`"))
    end

    tokens = split(firstline)
    if length(tokens) != 5
        throw(FileFormatException("Not enough words on first line, got $(length(tokens)) words"))
    end

    (head1, rep, field, symm) = map(lowercase, tokens[2:5])
    if head1 != "matrix"
        throw(FileFormatException("Unknown MatrixMarket data type: $head1 (only `matrix` is supported)"))
    end

    dimline = readline(stream)

    # Skip all comments and empty lines
    while length(chomp(dimline)) == 0 || (length(dimline) > 0 && dimline[1] == '%')
        dimline = readline(stream)
    end
    rows, cols, entries = parse_dimension(dimline, rep)

    return rows, cols, entries, rep, field, symm
end

"""
    mmread(filename, retcoord=false)

Read the contents of the Matrix Market file `filename` into a matrix, which will be either
sparse or dense, depending on the Matrix Market format indicated by `coordinate` (coordinate
sparse storage), or `array` (dense array storage).

# Arguments

- `filename::String`: The file to read.
- `retcoord::Bool`: If it is `true`, the rows, column and value vectors are returned along
    with the header information.
"""
function mmread(filename::String, retcoord::Bool=false)
    stream = open(filename, "r")
    rows, cols, entries, rep, field, symm = readinfo(stream)

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

    close(stream)

    return result
end

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

function hermitianize!(M::AbstractMatrix)
    M .+= tril(M, -1)'
    return M
end

function skewsymmetrize!(M::AbstractMatrix)
    M .-= tril(M, -1)'
    return M
end

generate_eltype(::Type{<:Bool}) = "pattern"
generate_eltype(::Type{<:Integer}) = "integer"
generate_eltype(::Type{<:AbstractFloat}) = "real"
generate_eltype(::Type{<:Complex}) = "complex"
generate_eltype(elty) = error("Invalid matrix type")

function generate_symmetric(m::AbstractMatrix)
    if issymmetric(m)
        return "symmetric"
    elseif ishermitian(m)
        return "hermitian"
    else
        return "general"
    end
end

function generate_entity(i, j, rows, vals, kind::String)
    nl = get_newline()
    if kind == "pattern"
        return "$(rows[j]) $i$nl"
    elseif kind == "complex"
        return "$(rows[j]) $i $(real(vals[j])) $(imag(vals[j]))$nl"
    else
        return "$(rows[j]) $i $(vals[j])$nl"
    end
end

"""
    mmwrite(filename, matrix)

Write a sparse matrix to .mtx file format.

# Arguments

- `filename::String`: The file to write.
- `matrix::SparseMatrixCSC`: The sparse matrix to write.
"""
function mmwrite(filename::String, matrix::SparseMatrixCSC)
    stream = open(filename, "w")
    mmwrite(stream, matrix)
    close(stream)
end

function mmwrite(stream::IO, matrix::SparseMatrixCSC)
    nl = get_newline()
    elem = generate_eltype(eltype(matrix))
    sym = generate_symmetric(matrix)

    # write header
    write(stream, "%%MatrixMarket matrix coordinate $elem $sym$nl")

    # only use lower triangular part of symmetric and Hermitian matrices
    if issymmetric(matrix) || ishermitian(matrix)
        matrix = tril(matrix)
    end

    # write matrix size and number of nonzeros
    write(stream, "$(size(matrix, 1)) $(size(matrix, 2)) $(nnz(matrix))$nl")

    rows = rowvals(matrix)
    vals = nonzeros(matrix)
    for i in 1:size(matrix, 2)
        for j in nzrange(matrix, i)
            entity = generate_entity(i, j, rows, vals, elem)
            write(stream, entity)
        end
    end
end

end # module
