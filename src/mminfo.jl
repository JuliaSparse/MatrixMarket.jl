"""
    mminfo(file)

Read header information on the size and structure from file. The actual data matrix is not
parsed.

# Arguments

- `file`: The filename or io stream.
"""
function mminfo(filename::String)
    mmfile = open(filename, "r")
    info = mminfo(mmfile)
    close(mmfile)
    return info
end

function mminfo(stream::IO)
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

struct FileFormatException <: Exception
    msg::String
end

Base.showerror(io::IO, e::FileFormatException) = print(io, e.msg)

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
