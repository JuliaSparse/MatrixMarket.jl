"""
    mmwrite(filename, matrix)

Write a sparse matrix to .mtx file format.

# Arguments

- `filename::String`: The file to write.
- `matrix::SparseMatrixCSC`: The sparse matrix to write.
"""
function mmwrite(filename::String, matrix::SparseMatrixCSC)
    stream = open(filename, "w")

    if endswith(filename, ".gz")
        stream = TranscodingStream(GzipCompressor(), stream)
    end

    mmwrite(stream, matrix)
    close(stream)
end

function mmwrite(stream::IO, matrix::SparseMatrixCSC{T}) where {T}
    nl = get_newline()
    elem = generate_eltype(T)
    writer = MMWriter(matrix)
    write(stream, header(writer))
    write(stream, nl)
    write(stream, sizetext(writer))
    write(stream, nl)

    for (r, c, v) in writer.format
        entity = generate_entity(r, c, v, elem)
        write(stream, entity)
        write(stream, nl)
    end
end

## Generating

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

function generate_entity(r, c, v, kind::String)
    if kind == "pattern"
        return "$r $c"
    elseif kind == "complex"
        return "$r $c $(real(v)) $(imag(v))"
    else
        return "$r $c $v"
    end
end

function get_newline()
    if Sys.iswindows()
        return "\r\n"
    else
        return "\n"
    end
end

## Writer

struct MMWriter{F <: MMFormat}
    nrow::Int
    ncol::Int
    nentry::Int
    symm::String
    format::F
end

function MMWriter(A::AbstractMatrix{T}) where {T}
    nrow, ncol = size(A)
    nentry = nrow * ncol
    vals = reshape(A, :)
    symm = generate_symmetric(A)
    format = ArrayFormat{T}(vals)
    return MMWriter{typeof(format)}(nrow, ncol, nentry, symm, format)
end

function MMWriter(A::SparseMatrixCSC)
    nrow, ncol = size(A)
    symm = generate_symmetric(A)

    # only use lower triangular part of symmetric and Hermitian matrices
    if symm == "symmetric" || symm == "hermitian"
        A = tril(A)
    end

    nentry = nnz(A)
    format = CoordinateFormat(A)
    return MMWriter{typeof(format)}(nrow, ncol, nentry, symm, format)
end

function header(writer::MMWriter)
    rep = formattext(writer.format)
    elem = generate_eltype(eltype(writer.format))
    return "%%MatrixMarket matrix $rep $elem $(writer.symm)"
end

sizetext(writer::MMWriter) = "$(writer.nrow) $(writer.ncol) $(writer.nentry)"
