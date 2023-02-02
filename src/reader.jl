struct MMReader{F <: MMFormat}
    nrow::Int
    ncol::Int
    nentry::Int
    rep::String
    symm::String
    format::F
end

function MMReader(nrow::Integer, ncol::Integer, nentry::Integer, rep, field, symm)
    format = (rep == "coordinate") ? CoordinateFormat(field, nentry) : ArrayFormat(nentry)
    return MMReader{typeof(format)}(nrow, ncol, nentry, rep, symm, format)
end

function readlines!(reader::MMReader, stream::IO)
    for i in 1:reader.nentry
        line = readline(stream)
        writeat!(reader.format, i, line)
    end
    return reader
end

function readout(reader::MMReader, retcoord::Bool=false)
    if retcoord
        return readout(reader.format, reader.nrow, reader.ncol, reader.nentry, reader.symm)
    else
        return readout(reader.format, reader.nrow, reader.ncol, reader.symm)
    end
end
