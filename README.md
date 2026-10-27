# MatrixMarket

[![CI](https://github.com/JuliaSparse/MatrixMarket.jl/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/JuliaSparse/MatrixMarket.jl/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/JuliaSparse/MatrixMarket.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaSparse/MatrixMarket.jl)

Package to read/write matrices from/to files in the [Matrix Market native exchange
format](https://math.nist.gov/MatrixMarket/formats.html#MMformat).

The [Matrix Market](https://math.nist.gov/MatrixMarket/) is a NIST repository of
"test data for use in comparative studies of algorithms for numerical linear
algebra, featuring nearly 500 sparse matrices from a variety of applications,
as well as matrix generation tools and services." Over time, the [Matrix Market's
native exchange format](https://math.nist.gov/MatrixMarket/formats.html#MMformat)
has become one of the _de facto_ standard file formats for exchanging matrix
data.

## Usage

```julia
] add MatrixMarket
```

### Read

```julia
using MatrixMarket
M = mmread("myfile.mtx")
```

Files in coordinate format are read into a `SparseMatrixCSC`, and files in array format
into a dense `Matrix`. If the header declares the matrix `symmetric`, `hermitian` or
`skew-symmetric`, only one triangle is stored in the file. `mmread` fills in the other
triangle and returns the full matrix as a plain `SparseMatrixCSC` or `Matrix`, not a
`Symmetric` or `Hermitian` wrapper.

The element type comes from the field in the header:

| Field     | Element type |
|-----------|--------------|
| `real`    | `Float64`    |
| `integer` | `Int64`      |
| `complex` | `ComplexF64` |
| `pattern` | `Bool`       |

Dense `integer` files are currently read as `Float64`.

To get the raw coordinate data instead of a matrix, pass `retcoord=true` as the third
positional argument:

```julia
rows, cols, vals, nrows, ncols, entries, rep, field, symm = mmread("myfile.mtx", false, true)
```

`rows`, `cols` and `vals` hold only the entries stored in the file. For symmetric files,
the other triangle is not added.

### Inspect the header

```julia
nrows, ncols, entries, rep, field, symm = mminfo("myfile.mtx")
```

`mminfo` parses only the header and the size line, not the matrix entries. `rep` is
`"coordinate"` or `"array"`, `field` is e.g. `"real"`, and `symm` is e.g. `"general"`.
For array files, `entries` is `nrows * ncols`. `mmread("myfile.mtx", true)` returns the
same tuple.

### Write

```julia
using SparseArrays
mmwrite("myfile.mtx", sparse(A))
```

`mmwrite` takes a `SparseMatrixCSC` and writes it in coordinate format. The field is
chosen from the element type: `Bool` becomes `pattern`, `Integer` becomes `integer`,
`AbstractFloat` becomes `real`, and `Complex` becomes `complex`. Any other element type
throws an error. If the matrix is symmetric or hermitian, only its lower triangle is
written, with the matching `symmetric` or `hermitian` header. Dense matrices are not
supported, so convert them with `sparse(A)` first.

### Compressed files and streams

If a filename ends in `.gz`, `mmread` and `mminfo` decompress it and `mmwrite`
compresses it:

```julia
mmwrite("myfile.mtx.gz", M)
M = mmread("myfile.mtx.gz")
```

All three functions also accept an `IO` stream instead of a filename:

```julia
M = open(mmread, "myfile.mtx")
info = open(mminfo, "myfile.mtx")
open(io -> mmwrite(io, M), "myfile.mtx", "w")
```

For example, to read a compressed matrix directly from the NIST collection:

```julia
using CodecZlib, Downloads
url = "https://math.nist.gov/pub/MatrixMarket2/Harwell-Boeing/platz/plsk1919.mtx.gz"
M = mmread(GzipDecompressorStream(seekstart(Downloads.download(url, IOBuffer()))))
```

## See also

[MatrixDepot.jl](https://github.com/JuliaLinearAlgebra/MatrixDepot.jl) downloads and caches
matrices by name from the [SuiteSparse Matrix Collection](https://sparse.tamu.edu/) and the
NIST Matrix Market, e.g. `mdopen("HB/1138_bus").A`.
