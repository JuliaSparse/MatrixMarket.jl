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
