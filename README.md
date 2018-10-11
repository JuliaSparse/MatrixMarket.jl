# MatrixMarket

[![Build Status](https://travis-ci.org/JuliaSparse/MatrixMarket.jl.svg?branch=master)](https://travis-ci.org/JuliaSparse/MatrixMarket.jl)

Package to read matrices from files in the [Matrix Market native exchange
format](http://math.nist.gov/MatrixMarket/formats.html#MMformat).

The [Matrix Market](http://math.nist.gov/MatrixMarket/) is a NIST repository of
"test data for use in comparative studies of algorithms for numerical linear
algebra, featuring nearly 500 sparse matrices from a variety of applications,
as well as matrix generation tools and services." Over time, the [Matrix Market's
native exchange format](http://math.nist.gov/MatrixMarket/formats.html#MMformat)
has become one of the _de facto_ standard file formats for exchanging matrix
data.

## Usage

    using MatrixMarket
    M = MatrixMarket.mmread("myfile.mtx")

`M` will be a sparse or dense matrix depending on whether the file contains a matrix
in coordinate format or array format. The specific type of `M` may be `Symmetric` or
`Hermitian` depending on the symmetry information contained in the file header.

    MatrixMarket.mmread("myfile.mtx", true)

Returns raw data from the file header. Does not read in the actual matrix elements

