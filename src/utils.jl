struct FileFormatException <: Exception
    msg::String
end

Base.showerror(io::IO, e::FileFormatException) = print(io, e.msg)

function get_newline()
    if Sys.iswindows()
        return "\r\n"
    else
        return "\n"
    end
end
