#Attempts to read every .mtx file in the test directory
using MatrixMarket

include("dl-matrixmarket.jl")

num_errors = 0
num_pass = 0

for filename in readdir()
    endswith(filename, ".mtx") || continue
    new_filename = "$(filename)_"
    try
        A = MatrixMarket.mmread(filename)
        println(filename, " : ", typeof(A), "  ", size(A))

        # verify mmread(mmwrite(A)) == A
        MatrixMarket.mmwrite(new_filename, A)
        new_A = MatrixMarket.mmread(new_filename)
        assert(new_A == A)

        num_pass += 1
    catch err
        println()
        println()
        println("PARSE ERROR")
        println(filename, " : ", err)
        if !isa(err, ErrorException)
            println(filter(x->x[1]!=Symbol("???"),
                    map(x->ccall(:jl_lookup_code_address, Any, (Ptr{Void}, Cint), x, true),
                    catch_backtrace())))
        end
        println()
        println()
        num_errors += 1
    finally
        rm(filename)
        rm(new_filename)
    end
end

println("Summary: $num_errors parse errors in $(num_errors + num_pass) matrices ")

exit(num_errors)
