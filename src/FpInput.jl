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

function formatinput(fp_input_path::String)
    fp_input_files = readdir(fp_input_path)
    m = [match(r"\d{8}$", file).match for file in fp_input_files]
    m_sep = [parse.(Int, [x[1:2], x[3:4], x[5:6], x[7:8]]) for x in m]
    formated_date = [DateTime(y, m, d, h) for (y, m, d, h) in m_sep]
    dates = dateYY.(formated_date)
    [Dates.format(d, "yyyymmdd")*" "*Dates.format(d, "HHMMSS")*"      "*fn*"      "*"ON DISK" for (d, fn) in zip(dates, fp_input_files)]

    # write_formated_av(formated_av)
end

function formatinput(dates:: Array{DateTime, 1}, prefix::String)
    fname = prefix .* Dates.format.(dates, "yymmddHH")
    [Dates.format(d, "yyyymmdd")*" "*Dates.format(d, "HHMMSS")*"      "*fn*"      "*"ON DISK" for (d, fn) in zip(dates, fname)]
end

function update_available(fpdir::FlexpartDir, dates:: Array{DateTime, 1}, prefix::String)
    formated = formatinput(dates, prefix)
    avpath = getdir(fpdir, :available)
    update_available(avpath, formated)
end

function update_available(fpdir::FlexpartDir)
    formated = formatinput(getdir(fpdir, :input))
    avpath = getdir(fpdir, :available)
    update_available(avpath, formated)
end

function update_available(avpath::String, formated::Vector{<:String})
    av_file = readlines(avpath)
    ioc = findfirst(x -> occursin("YYYYMMDD HHMMSS", x), av_file)
    new_av = isnothing(ioc) ? [] : av_file[1:ioc[1]]
    for l in formated
        push!(new_av, l)
    end
    open(avpath, "w") do f
        for l in new_av
            Base.write(f, l*"\n")
        end
    end
end