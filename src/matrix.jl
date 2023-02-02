function hermitianize!(M::AbstractMatrix)
    M .+= tril(M, -1)'
    return M
end

function skewsymmetrize!(M::AbstractMatrix)
    M .-= tril(M, -1)'
    return M
end
