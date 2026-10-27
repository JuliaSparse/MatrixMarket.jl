"""
    mmwrite(filename, matrix)

Write a sparse matrix to .mtx file format. If `filename` ends in `.gz`, the output is
gzip-compressed.

# Arguments

- `filename::AbstractString`: The file to write.
- `matrix::SparseMatrixCSC`: The sparse matrix to write.
"""
function mmwrite(filename::AbstractString, matrix::SparseMatrixCSC)
    open(filename, "w") do io
        if endswith(filename, ".gz")
            # Closing the compressor flushes the gzip trailer; it also closes `io`.
            stream = GzipCompressorStream(io)
            try
                mmwrite(stream, matrix)
            finally
                close(stream)
            end
        else
            mmwrite(io, matrix)
        end
    end
end

function mmwrite(stream::IO, matrix::SparseMatrixCSC)
    nl = "\n"
    elem = generate_eltype(eltype(matrix))
    sym = generate_symmetric(matrix)

    # write header
    write(stream, "%%MatrixMarket matrix coordinate $elem $sym$nl")

    # only use lower triangular part of symmetric and Hermitian matrices
    if sym != "general"
        matrix = tril(matrix)
    end

    # write matrix size and number of nonzeros
    write(stream, "$(size(matrix, 1)) $(size(matrix, 2)) $(nnz(matrix))$nl")

    rows = rowvals(matrix)
    vals = nonzeros(matrix)
    for i in 1:size(matrix, 2)
        for j in nzrange(matrix, i)
            write_entity(stream, i, j, rows, vals, elem)
        end
    end
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

# Print each entry straight to the stream instead of building an intermediate string.
function write_entity(stream::IO, i, j, rows, vals, kind::String)
    if kind == "pattern"
        print(stream, rows[j], ' ', i, '\n')
    elseif kind == "complex"
        print(stream, rows[j], ' ', i, ' ', real(vals[j]), ' ', imag(vals[j]), '\n')
    else
        print(stream, rows[j], ' ', i, ' ', vals[j], '\n')
    end
end
