struct Available
    header::String
    files::Vector{NamedTuple}
end
function Available()
    header = "YYYYMMDD HHMMSS   name of the file(up to 80 characters)"
    new(header, Vector{NamedTuple}())
end
function Available(path::String)
    lines = readlines(path)
    ioc = findfirst(x -> occursin("YYYYMMDD HHMMSS", x), lines)
    headerlines = isnothing(ioc) ? [] : lines[1:ioc[1]]
    header = join(headerlines, "\n")
    filelines = isnothing(ioc) ? lines : lines[ioc+1:end]
    files = NamedTuple[]
    for l in filelines
        sl = split(l)
        date = DateTime(sl[1]*sl[2], "yyyymmddHHMMSS")
        push!(files, (date=date, filename=sl[3]))
    end
    Available(header, files)
end
Available(fpdir::FlexpartDir) = Available(getdir(fpdir, :available))
Base.show(io::IO, available::Available) = Base.display(available.files)

function write(available::Available, path::String)
    (tmppath, tmpio) = mktemp()

    for line in format(available) Base.write(tmpio, line*"\n") end

    close(tmpio)
    dest = path

    mv(tmppath, dest, force=true)
end

function write(fpdir::FlexpartDir, available::Available)
    write(available, getdir(fpdir, :available))
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

function format(available::Available)
    strs = [available.header]
    for elem in available.files
        str = Dates.format(elem.date, "yyyymmdd")*" "*Dates.format(elem.date, "HHMMSS")*"      "*elem.filename*"      "*"ON DISK"
        push!(strs, str)
    end
    strs
end


function update(available::Available, inputdir::String)
    files = readdir(inputdir)
    newfiles = NamedTuple[]

    for file in files
        m = match(r"^([A-Z]*)(\d{8,10})$", file)
        if !isnothing(m)
            x = m.captures[2]
            m_sep = parse.(Int, [x[1:2], x[3:4], x[5:6], x[7:8]])
            formated_date = DateTime(m_sep...)
            push!(newfiles, (date=dateYY.(formated_date), filename=file))
        end
    end
    Available(available.header, newfiles)
end

function update(available::Available, dates::Vector{DateTime}, prefix::String)
    fnames = prefix .* Dates.format.(dates, "yymmddHH")
    Available(available.header, [(date=date, filename=fname) for (date, fname) in zip(dates, fnames)])
end

function updated_available(fpdir::FlexpartDir)
    update(Available(fpdir), getdir(fpdir, :input))
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