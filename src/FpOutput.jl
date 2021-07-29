function find_ncf()
    out_dir = joinpath(FP_DIR, OUTPUT_DIR)
    out_files = readdir(out_dir)
    ncf = filter(x -> occursin(".nc", x), out_files)
    global NCF_OUTPUT = joinpath(out_dir, ncf[1])
    joinpath.(out_dir, ncf)
end

function outclear()
    global NCF_OUTPUT = ""
end

function ncf_empty(f, args=nothing::Union{Nothing, Tuple})
    global NCF_OUTPUT
    if NCF_OUTPUT == ""
        throw("No output file has been loaded")
    end
    if isnothing(args)
        f(NCF_OUTPUT)
    else
        f(NCF_OUTPUT, args...)
    end
        
end

outinfo(file) = ncinfo(file)
outinfo() = ncf_empty(outinfo)

function mesh(file)
    lat = ncread(file, "latitude"); lon = ncread(file, "longitude")
    lon, lat
end
mesh() = ncf_empty(mesh)

function deltamesh(lons, lats)
    dxs = lons[2:end] - lons[1:end-1]
    dys = lats[2:end] - lats[1:end-1]

    dx = unique(round.(dxs, digits=5))
    dy = unique(round.(dys, digits=5))

    if (length(dx) != 1) || (length(dy) != 1)
        throw(ErrorException("mesh is not uniform"))
    end

    dx[1], dy[1]
end

conc(file::String) = ncread(file, "spec001_mr")
conc() = ncf_empty(conc)
conc(file::String, timestep::Integer) = conc(file)[:,:,1,timestep,1,1]
conc(timestep::Integer) = ncf_empty(conc, (timestep))

conc_diskarray(file::String) = NetCDF.open(file, "spec001_mr")
conc_diskarray() = ncf_empty(conc_diskarray)

wetdep(file::String) = ncread(file, "WD_spec001")
wd_diskarray(file::String) = NetCDF.open(file, "WD_spec001")

function all_dataset(file::String)
    lat = ncread(file, "latitude"); lon = ncread(file, "longitude"); spec = ncread(file, "spec001_mr");
    z = spec[:,:,:,:,:,:]
    lon, lat, z
end
all_dataset() = ncf_empty(all_dataset)

function fields(file::String, timestep::Integer)
    lat = ncread(file, "latitude"); lon = ncread(file, "longitude"); spec = ncread(file, "spec001_mr");
    z = spec[:,:,1,timestep,1,1]
    lon, lat, z
end
fields(timestep::Integer) = ncf_empty(fields, (timestep))

function filtered_fields(file::String, timestep::Integer)
    lon, lat, z = fields(file, timestep)
    mask = (!).(isapprox.(0., z))

    mg_lon = lon .* ones(length(lat))'
    mg_lat = lat' .* ones(length(lon))

    return mg_lon[mask], mg_lat[mask], z[mask]
end
filtered_fields(timestep::Integer) = ncf_empty(filtered_fields, (timestep))

function filter_fields(lon, lat, conc)
    if size(conc) != (length(lon), length(lat)) throw("dimension mismatch : size(conc) == (length(lon), length(lat))") end
    mask = (!).(isapprox.(0., conc))

    mg_lon = lon .* ones(length(lat))'
    mg_lat = lat' .* ones(length(lon))

    return mg_lon[mask], mg_lat[mask], conc[mask]
end

function relloc(file)
    rellats = ncread(file, "RELLAT1") |> unique
    rellons = ncread(file, "RELLNG1") |> unique
    # [[lon, lat] for (lon, lat) in zip(rellons, rellats)]
    rellons, rellats
end
relloc() = ncf_empty(relloc)

heights(file) = ncread(file, "height")

function time_average(alltimes::Union{Array{Float32, 3}, Array{Float64, 3}})

    added = zeros(eltype(alltimes), size(alltimes)[1:2])
    N = length(alltimes[1, 1, :])
    for i=1:N
        added += alltimes[:, :, i]
    end
    
    return added ./ N
end

function split_days(times::Vector{DateTime})
    split = Vector{Vector{Int}}()
    prev_day = Dates.day(times[1]) 
    day_inds = Vector{Int}()
    for (index, time) in enumerate(times)
        cur_day = Dates.day(time)
        if cur_day == prev_day
            push!(day_inds, index)
        else
            push!(split, day_inds)
            day_inds = Vector{Int}()
            push!(day_inds, index)
            prev_day = cur_day
        end
    end
    split
end

function daily_average(alltimes::Union{Array{Float32, 3}, Array{Float64, 3}}, times::Vector{DateTime})

    split = split_days(times)
    daily_av = zeros(eltype(alltimes), (size(alltimes)[1:2]..., length(split)))
    for (index, day_index) in enumerate(split)
        days = alltimes[:, :, day_index];
        daily_av[:, :, index] = time_average(days)
    end
    return daily_av
end

function add_time_average(file)
    dataset = Flexpart.conc(file)
    s = size(dataset)
    new_dataset = zeros(s[1], s[2], s[3], s[5], s[6])
    for height in 1:s[3], pointspec in 1:s[5], nageclass in 1:s[6]
        new_dataset[:,:,height, pointspec, nageclass] = time_average(dataset[:,:,height, :, pointspec, nageclass])
    end

    attribs = Dict(
        "units" => "ng m-3",
        "long_name" => "time average conc"
    )
    nccreate(file, "time_av", 
        "longitude", 
        "latitude",
        "height",
        "pointspec",
        "nageclass",
        atts=attribs)

    ncwrite(new_dataset, file, "time_av")
end

function add_daily_average(file)
    name = "daily_av"
    dataset = Flexpart.conc(file)
    s = size(dataset)
    times = times_dt(file)
    ndays = split_days(times) |> length
    new_dataset = zeros(s[1], s[2], s[3], s[5], s[6], ndays)

    for height in 1:s[3], pointspec in 1:s[5], nageclass in 1:s[6]
        new_dataset[:,:,height, pointspec, nageclass, :] = daily_average(dataset[:,:,height, :, pointspec, nageclass], times)
    end

    attribs = Dict(
        "units" => "ng m-3",
        "long_name" => "time average conc"
    )

    nccreate(file, name, 
        "longitude", 
        "latitude",
        "height",
        "pointspec",
        "nageclass",
        "ndays", ndays,
        atts=attribs)

    ncwrite(new_dataset, file, name)
end

function start_dt(file)
    Dates.DateTime(ncgetatt(file, "Global", "ibdate")*ncgetatt(file, "Global", "ibtime"), dateformat"yyyymmddHHMMSS")
end

function end_dt(file)
    Dates.DateTime(ncgetatt(file, "Global", "iedate")*ncgetatt(file, "Global", "ietime"), dateformat"yyyymmddHHMMSS")
end

function split_days(times::Vector{DateTime})
    split = Vector{Vector{Int}}()
    cur_day = Dates.day(times[1]) 
    day_inds = Vector{Int}()
    for (index, time) in enumerate(times)
        day = Dates.day(time)
        if day == cur_day
            push!(day_inds, index)
        else
            push!(split, day_inds)
            day_inds = Vector{Int}()
            push!(day_inds, index)
            cur_day = day
        end
    end
    return split
end

function times_dt(file)::Vector{DateTime}
    startdate = start_dt(file)

    times = convert.(Int, ncread(file, "time") ./ 3600)

    return [startdate + Dates.Hour(x) for x in times]
end
