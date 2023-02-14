abstract type MMFormat end

Base.length(f::MMFormat) = length(f.vals)

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

function CoordinateFormat(A::SparseMatrixCSC{T}) where {T}
    rows = rowvals(A)
    vals = nonzeros(A)
    n = size(A, 2)
    cols = [repeat([j], length(nzrange(A, j))) for j in 1:n]
    cols = collect(Iterators.flatten(cols))
    return CoordinateFormat{T}(rows, cols, vals)
end

Base.eltype(::CoordinateFormat{T}) where T = T

formattext(::CoordinateFormat) = "coordinate"

Base.Tuple(f::CoordinateFormat) = (f.rows, f.cols, f.vals)

Base.:(==)(x::CoordinateFormat, y::CoordinateFormat) = (x.rows == y.rows) &&
    (x.cols == y.cols) && (x.vals == y.vals)

function writeat!(f::CoordinateFormat{T}, i::Int, line::String) where T
    f.rows[i], f.cols[i], f.vals[i] = parseline(T, line)
    return f
end

function readout(f::CoordinateFormat, nrow::Int, ncol::Int, symm)
    symfunc = parse_symmetric(symm)
    return symfunc(sparse(f.rows, f.cols, f.vals, nrow, ncol))
end

function Base.iterate(f::CoordinateFormat, i::Integer=zero(length(f)))
    i += oneunit(i)
    if i <= length(f)
        return (f.rows[i], f.cols[i], f.vals[i]), i
    else
        return nothing
    end
end

struct ArrayFormat{T} <: MMFormat
    vals::Vector{T}
end

function ArrayFormat(::Type{T}, nentry::Int) where {T}
    vals = Vector{T}(undef, nentry)
    return ArrayFormat{T}(vals)
end

ArrayFormat(nentry::Int) = ArrayFormat(Float64, nentry)

ArrayFormat(A::AbstractMatrix{T}) where {T} = ArrayFormat{T}(reshape(A, :))

Base.eltype(::ArrayFormat{T}) where T = T

formattext(::ArrayFormat) = "array"

Base.Tuple(f::ArrayFormat) = (f.vals,)

Base.:(==)(x::ArrayFormat, y::ArrayFormat) = (x.vals == y.vals)

function writeat!(f::ArrayFormat{T}, i::Int, line::String) where T
    f.vals[i] = parse(T, line)
    return f
end

function readout(f::ArrayFormat, nrow::Int, ncol::Int, symm)
    A = reshape(f.vals, nrow, ncol)
    symfunc = parse_symmetric(symm)
    return symfunc(A)
end

function Base.iterate(f::ArrayFormat, i::Integer=zero(length(f)))
    i += oneunit(i)
    if i <= length(f)
        return f.vals[i], i
    else
        return nothing
    end
end
