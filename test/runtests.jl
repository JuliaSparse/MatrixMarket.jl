#Attempts to read every .mtx file in the test directory
using MatrixMarket

#include("dl-matrixmarket.jl")

num_errors = 0
num_pass = 0
for filename in readdir("../src/data/")
    endswith(filename, ".mtx") || continue
    try
        A = MatrixMarket.mmread("../src/data/$filename")
        println(filename, " : ", typeof(A), "  ", size(A))
        num_pass += 1
    catch err
	println()
	println()
	println("PARSE ERROR")
        println(filename, " : ", typeof(err), " : ", :msg in names(err) ? err.msg : "")
        isa(err, ErrorException) || println(filter(x->x[1]!=symbol("???"), map(x->ccall(:jl_lookup_code_address, Any, (Ptr{Void}, Cint), x, true), catch_backtrace())))
	println()
	println()
	num_errors += 1
    end
end

println("Summary: $num_errors parse errors in $(num_errors + num_pass) matrices ")

exit(num_errors)
