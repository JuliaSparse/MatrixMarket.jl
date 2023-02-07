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

function get_newline()
    if Sys.iswindows()
        return "\r\n"
    else
        return "\n"
    end
end
