include("FpOption.jl")


function write(relctrl::Releases_ctrl, rels::Vector{Release})
    (tmppath, tmpio) = mktemp()

    write(tmpio, relctrl)
    write(tmpio, rels)

    close(tmpio)
    dest = joinpath(FP_DIR, OPTIONS_DIR, "RELEASES")

    mv(tmppath, dest, force=true)
end

function write(outgrid::Outgrid)
    (tmppath, tmpio) = mktemp()

    write(tmpio, outgrid)

    close(tmpio)
    dest = joinpath(FP_DIR, OPTIONS_DIR, "OUTGRID")

    mv(tmppath, dest, force=true)
end

function write(outgrid::OutgridN)
    (tmppath, tmpio) = mktemp()

    write(tmpio, outgrid)

    close(tmpio)
    dest = joinpath(FP_DIR, OPTIONS_DIR, "OUTGRID_NEST")

    mv(tmppath, dest, force=true)
end

function write(outgrid::Command)
    (tmppath, tmpio) = mktemp()

    write(tmpio, outgrid)

    close(tmpio)
    dest = joinpath(FP_DIR, OPTIONS_DIR, "COMMAND")

    mv(tmppath, dest, force=true)
end

function dateYY(d)
    y = Dates.year(d)
    if 80 <= y <= 99
        d+Dates.Year(1900)
    elseif 0 <= y <= 79
        d+Dates.Year(2000)
    else
        error("don't know what to do with year $d")
    end
end
function update_available(fp_input_path::String)
    fp_input_files = readdir(fp_input_path)
    m = [match(r"\d{8}$", file).match for file in fp_input_files]
    m_sep = [parse.(Int, [x[1:2], x[3:4], x[5:6], x[7:8]]) for x in m]
    formated_date = [DateTime(y, m, d, h) for (y, m, d, h) in m_sep]
    dates = dateYY.(formated_date)
    formated_av = [Dates.format(d, "yyyymmdd")*" "*Dates.format(d, "HHMMSS")*"      "*fn*"      "*"ON DISK" for (d, fn) in zip(dates, fp_input_files)]

    write_formated_av(formated_av)
end

function update_available(dates:: Array{DateTime, 1}, prefix::String)
    fname = prefix .* Dates.format.(dates, "yymmddHH")
    formated_av = [Dates.format(d, "yyyymmdd")*" "*Dates.format(d, "HHMMSS")*"      "*fn*"      "*"ON DISK" for (d, fn) in zip(dates, fname)]

    write_formated_av(formated_av)
end

function write_formated_av(formated_av::Vector{String})
    av_file = readlines(AVAILABLE)
    ioc = findall(x -> occursin("YYYYMMDD HHMMSS", x), av_file)
    new_av = av_file[1:ioc[1]]
    for l in formated_av
        push!(new_av, l)
    end
    open(AVAILABLE, "w") do f
        for l in new_av
            write(f, l*"\n")
        end
    end
end

function namelist2dict(filepath)
    fieldtype = Union{String, Dict, SubString{String}}
    d = Dict{Symbol, fieldtype}()
    f = open(filepath, "r")
    header = ""
    for line in eachline(f)
        if !((m = match(r"\s*(.*?)\s*=\s*([^\s,]*)\s*,", line)) |> isnothing) #captures the field name in group 1 and the value in group 2
            dict2fill = header |> isempty ? d : d[Symbol(header)]
            push!(dict2fill, m.captures[1] |> Symbol => m.captures[2])
        elseif !((m = match(r"\&(\w*)", line)) |> isnothing) #captures the name of the header in group 1
            push!(d, m.captures[1] |> Symbol => Dict{Symbol, fieldtype}())
            header = m.captures[1]
        end
    end
    close(f)
    d
end

function option2dict(opt_name)
    path = joinpath(FP_DIR, OUTPUT_DIR, uppercase(opt_name) * ".namelist")
    namelist2dict(path)
end