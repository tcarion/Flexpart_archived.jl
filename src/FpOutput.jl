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

function grid(file)
    lat = ncread(file, "latitude"); lon = ncread(file, "longitude")
    lon, lat
end
grid() = ncf_empty(grid)

conc(file) = ncread(file, "spec001_mr")
conc() = ncf_empty(conc)
conc(file, timestep::Integer) = conc(file)[:,:,1,timestep,1,1]
conc(timestep::Integer) = ncf_empty(conc, (timestep))

conc_diskarray(file::String) = NetCDF.open(file, "spec001_mr")

conc_diskarray() = ncf_empty(conc_diskarray)

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

function relloc(file)
    rellats = ncread(file, "RELLAT1") |> unique
    rellons = ncread(file, "RELLNG1") |> unique
    # [[lon, lat] for (lon, lat) in zip(rellons, rellats)]
    rellons, rellats
end
relloc() = ncf_empty(relloc)