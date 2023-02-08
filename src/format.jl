abstract type MMFormat end

function readout(f::MMFormat, nrow::Int, ncol::Int, nentry::Int, symm)
    rep = formattext(f)
    field = generate_eltype(eltype(f))
    return (Tuple(f)..., nrow, ncol, nentry, rep, field, symm)
end

struct CoordinateFormat{T} <: MMFormat
    rows::Vector{Int}
    cols::Vector{Int}
    vals::Vector{T}
end

function CoordinateFormat(field, nentry)
    T = parse_eltype(field)
    rows = Vector{Int}(undef, nentry)
    cols = Vector{Int}(undef, nentry)
    vals = Vector{T}(undef, nentry)
    return CoordinateFormat{T}(rows, cols, vals)
end

Base.eltype(::CoordinateFormat{T}) where T = T

formattext(::CoordinateFormat) = "coordinate"

Base.Tuple(f::CoordinateFormat) = (f.rows, f.cols, f.vals)

function writeat!(f::CoordinateFormat{T}, i::Int, line::String) where T
    f.rows[i], f.cols[i], f.vals[i] = parseline(T, line)
    return f
end

function readout(f::CoordinateFormat, nrow::Int, ncol::Int, symm)
    symfunc = parse_symmetric(symm)
    return symfunc(sparse(f.rows, f.cols, f.vals, nrow, ncol))
end

struct ArrayFormat{T} <: MMFormat
    vals::Vector{T}
end

function ArrayFormat(::Type{T}, nentry::Int) where {T}
    vals = Vector{T}(undef, nentry)
    return ArrayFormat{T}(vals)
end

ArrayFormat(nentry::Int) = ArrayFormat(Float64, nentry)

Base.eltype(::ArrayFormat{T}) where T = T

formattext(::ArrayFormat) = "array"

Base.Tuple(f::ArrayFormat) = (f.vals,)

function writeat!(f::ArrayFormat{T}, i::Int, line::String) where T
    f.vals[i] = parse(T, line)
    return f
end

function readout(f::ArrayFormat, nrow::Int, ncol::Int, symm)
    A = reshape(f.vals, nrow, ncol)
    symfunc = parse_symmetric(symm)
    return symfunc(A)
end
