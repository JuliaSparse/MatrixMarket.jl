"""
    readinfo(stream)
    readinfo(file)

Read header information on the size and structure from `file` or `stream`. The actual data
matrix is not parsed.

# Arguments

- `file::AbstractString`: The filename to read.
- `stream::IO`: The stream to read.
"""
function readinfo(filename::AbstractString)
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
    mmread(stream, retcoord=false)
    mmread(filename, retcoord=false)

Read the contents of the Matrix Market file `filename` or `stream` into a matrix, which will
be either sparse or dense, depending on the Matrix Market format indicated by `coordinate`
(coordinate sparse storage), or `array` (dense array storage).

# Arguments

- `filename::AbstractString`: The file to read.
- `stream::IO`: The stream to read.
- `retcoord::Bool`: If it is `true`, the rows, column and value vectors are returned along
    with the header information.
"""
function mmread(filename::AbstractString, retcoord::Bool=false)
    stream = open(filename, "r")
    result = mmread(stream, retcoord)
    close(stream)

    return result
end

function mmread(stream::IO, retcoord::Bool=false)
    nrow, ncol, nentry, rep, field, symm = readinfo(stream)
    reader = MMReader(nrow, ncol, nentry, rep, field, symm)
    readlines!(reader, stream)
    return readout(reader, retcoord)
end

"""
    mmwrite(stream, matrix)
    mmwrite(filename, matrix)

Write a sparse matrix to .mtx file format or `stream`.

# Arguments

- `filename::AbstractString`: The file to write.
- `stream::IO`: The stream to write.
- `matrix::SparseMatrixCSC`: The sparse matrix to write.
"""
function mmwrite(filename::AbstractString, matrix::SparseMatrixCSC)
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
