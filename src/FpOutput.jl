mutable struct MetaData{T<:Real}
    startd::DateTime
    endd::DateTime
    times::Vector{DateTime}
    totparts::Int
    rellats::Vector{T}
    rellons::Vector{T}
end

mutable struct FlexpartOutput
    filename::String
    lons::Vector{Real}
    lats::Vector{Real}
    ncdataset::Union{NCDatasets.NCDataset, Nothing}
    dataset::Union{Array{Real}, Nothing}
    ncvar::Union{NCDatasets.CFVariable, Nothing}
    # remdim::Union{NamedTuple, Nothing}
    selected::Union{Dict{Symbol, Any}, Nothing}
    metadata::MetaData
end

function FlexpartOutput(filename::String)
    filename = abspath(filename)
    lons, lats = mesh(filename)
    FlexpartOutput(filename, lons, lats, NCDataset(filename, "r"), nothing, nothing, Dict(), MetaData(filename))
end

FlexpartOutput(fpdir::FlexpartDir, name::String) = FlexpartOutput(joinpath(fpdir.path, OUTPUT_DIR, name))
FlexpartOutput(path::String, name::String) = FlexpartOutput(FlexpartDir(path), name)

function ncf_files(fpdir::FlexpartDir; onlynested=false)
    out_files = readdir(joinpath(fpdir.path, OUTPUT_DIR))
    f = onlynested ? x -> occursin("nest.nc", x) :  x ->  occursin(".nc", x)
    files = filter(f, out_files)
    [joinpath(fpdir.path, OUTPUT_DIR, x) for x in files]
end

ncf_files(path::String; onlynested=false) = ncf_files(FlexpartDir(path), onlynested=onlynested)


function MetaData(filename::String)
    NCDataset(filename, "r") do ds
        rellats, rellons = relloc(filename)
        parts = ds["RELPART"]
        MetaData(start_dt(filename), end_dt(filename), times_dt(filename), sum(parts), rellats, rellons)
    end
end

hasfield2d(output::FlexpartOutput) = output.dataset isa Matrix

hasselection(output::FlexpartOutput) = output.ncvar !== nothing
# isspatial(output::FlexpartOutput) = (length(size(output.field)) == 2)
function variables2d(output::FlexpartOutput)
    variables = keys(output.ncdataset)
    inds = findall( x ->
        try 
            size(output.ncdataset[x])[1:2] == (length(output.lons), length(output.lats))
        catch
            false
        end,
        variables
        )
    variables[inds]
end

function remdim(output::FlexpartOutput)
    hasselection(output) &&
    try
        remdim(output.ncvar)
    catch
        throw(ArgumentError("A variable has to be selected"))
    end
end
function remdim(ds::NCDatasets.CFVariable)
    names = NCDatasets.dimnames(ds)
    sizes = NCDatasets.dimsize(ds)
    NamedTuple{Symbol.(names[3:end])}(sizes)
end

attrib(output::FlexpartOutput) = Dict(output.ncdataset.attrib)
attrib(ds::NCDatasets.NCDataset) = Dict(ds.attrib)
attrib(ds::NCDatasets.CFVariable) = push!(Dict(ds.attrib), "name" => NCDatasets.name(ds))
function attrib(filename::String)
    NCDataset(filename, "r") do ds
        attrib(ds)
    end
end

function alldims(ds::NCDatasets.NCDataset, ncvar::NCDatasets.CFVariable) :: Dict{Symbol, Vector{Any}}
    dims = remdim(ncvar)
    d = Dict{Symbol,  Vector{Any}}()
    for k in keys(dims)
        try
            push!(d, k => ds[k][:])
        catch
            push!(d, k => 1:dims[k] |> collect)
        end
    end
    d
end
function alldims(output::FlexpartOutput)
    hasselection(output) || error("No variable has been selected")
    alldims(output.ncdataset, output.ncvar)
end

clearselected!(output::FlexpartOutput) = output.selected = Dict()

function select!(output::FlexpartOutput, var::String)
    dataset = try
        output.ncdataset[var]
    catch
        throw(ArgumentError("the selected variable doesn't exist or file is closed"))
    end
    isfield = try 
        size(dataset)[1:2] == (length(output.lons), length(output.lats))
    catch
        false
    end
    if isfield
        # output.ncdataset = dataset
        # output.dataset = dataset[:]
        output.ncvar = dataset
        clearselected!(output)

        # output.remdim = try 
        #     remdim(dataset)
        # catch 
        #     nothing
        # end
    else
        @warn "The variable is not a spatial field, it won't be added to FlexpartOutput"
    end
    dataset
end


function select!(output::FlexpartOutput, dims::NamedTuple)
    hasselection(output) || error("No variable has been selected")
    clearselected!(output)
    rd = remdim(output)
    indices = []
    for k in keys(rd)
        if k in keys(dims)
            push!(indices, dims[k])
        else
            push!(indices, :)
        end
    end
    nt = NamedTuple{keys(rd)}(indices)
    for k in keys(dims)
        try
            push!(output.selected, k => output.ncdataset[k][dims[k]])
        catch
            push!(output.selected, k => dims[k])
        end
    end
    output.dataset = output.ncvar[:,:,nt...]
    output
end

function select!(output::FlexpartOutput, dims::Dict)
    hasselection(output) || error("No variable has been selected")
    adims = alldims(output)
    indices = []
    for (k,v) in dims
        v = try
            v = try
                parse(Float64, v)
            catch
                v
            end
            d = adims[k][1]
            v, d = try
                convert(Float64, v), convert(Float64, d)
            catch
                v, d
            end
            # @bp
            typev = typeof(v)
            typed = typeof(d)
            # typev = typev <: AbstractFloat ? Float64 : typev
            # typed = typed <: AbstractFloat ? Float64 : typed
            typev == typed ?
                v : 
                parse_date([(v, "yyyymmddTHHMMSS"), (v[1:19], "yyyy-mm-ddTHH:MM:SS")])
        catch
            error("Wrong type to be selected")
        end

        inds = try
            findall(x -> x == v, adims[k])[1]
        catch
            error("Some selected variables don't exist")
        end
        push!(indices, inds)
    end
    ndims = NamedTuple{Tuple(keys(dims) |> collect)}(indices)
    select!(output, ndims)
end

function parse_date(args::Vector{Tuple{String, String}})
    # formats = ["yyyymmddTHHMMSS", "yyyy-mm-ddTHH:MM:SS"]
    tried = []
    err = nothing
    for arg in args
        t = try
            DateTime(arg...)
        catch ex
            err = ex
            nothing
        end
        !isnothing(t) && push!(tried, t)
    end

    length(tried) == 0 && throw(err)
    tried[1]
end

# function find_ncf()
#     out_dir = joinpath(FP_DIR, OUTPUT_DIR)
#     out_files = readdir(out_dir)
#     ncf = filter(x -> occursin(".nc", x), out_files)
#     global NCF_OUTPUT = joinpath(out_dir, ncf[1])
#     joinpath.(out_dir, ncf)
# end

# function outclear()
#     global NCF_OUTPUT = ""
# end

# function ncf_empty(f, args=nothing::Union{Nothing, Tuple})
#     global NCF_OUTPUT
#     if NCF_OUTPUT == ""
#         throw("No output file has been loaded")
#     end
#     if isnothing(args)
#         f(NCF_OUTPUT)
#     else
#         f(NCF_OUTPUT, args...)
#     end
        
# end

# outinfo(file) = ncinfo(file)

function mesh(file)
    NCDataset(file, "r") do ds
        lon = ds["longitude"]; lat = ds["latitude"]
        lon[:], lat[:]
    end
end

# getvar(file::String, var::String) = NCDataset(file, "r")[var]

function deltamesh(lons, lats)
    dxs = lons[2:end] - lons[1:end-1]
    dys = lats[2:end] - lats[1:end-1]

    dx = unique(round.(dxs, digits=5))
    dy = unique(round.(dys, digits=5))

    if (length(dx) != 1) || (length(dy) != 1)
        error("mesh is not uniform")
    end

    dx[1], dy[1]
end

function areamesh(lons, lats)
    min_lon = minimum(lons)
    max_lon = maximum(lons)
    if min_lon > 180 || max_lon > 180
        min_lon -= 360
        max_lon -= 360
    end
    if min_lon < -180 || max_lon < -180
        min_lon += 360
        max_lon += 360
    end
    [maximum(lats), min_lon, minimum(lats), max_lon]
end
# conc(file::String) = getvar(file, "spec001_mr")[:]
# conc(file::String, timestep::Integer) = conc(file)[:,:,1,timestep,1,1]


# wetdep(file::String) =  getvar(file, "WD_spec001")[:]

# function all_dataset(file::String)
#     lat = ncread(file, "latitude"); lon = ncread(file, "longitude"); spec = ncread(file, "spec001_mr");
#     z = spec[:,:,:,:,:,:]
#     lon, lat, z
# end
# all_dataset() = ncf_empty(all_dataset)

function fields(file::String, var::String)
    lat, lon = mesh(file); spec = getvar(file, var)[:];
    lon, lat, z
end
# fields(timestep::Integer) = ncf_empty(fields, (timestep))

# function filtered_fields(file::String, timestep::Integer)
#     lon, lat, z = fields(file, timestep)
#     mask = (!).(isapprox.(0., z))

#     mg_lon = lon .* ones(length(lat))'
#     mg_lat = lat' .* ones(length(lon))

#     return mg_lon[mask], mg_lat[mask], z[mask]
# end
# filtered_fields(timestep::Integer) = ncf_empty(filtered_fields, (timestep))

function filter_fields(lon, lat, field)
    if size(field) != (length(lon), length(lat)) error("dimension mismatch : size(field) == (length(lon), length(lat))") end
    mask = (!).(isapprox.(0., field))

    mg_lon = lon .* ones(length(lat))'
    mg_lat = lat' .* ones(length(lon))

    return mg_lon[mask], mg_lat[mask], field[mask]
end

function relloc(file)
    NCDataset(file, "r") do ds
        rellats = ds["RELLAT1"] |> unique
        rellons = ds["RELLNG1"] |> unique
        # [[lon, lat] for (lon, lat) in zip(rellons, rellats)]
        rellons, rellats
    end
end
# relloc() = ncf_empty(relloc)

# heights(file) = ncread(file, "height")

function faverage(alltimes::Union{Array{Float32, 3}, Array{Float64, 3}, Array{Real, 3}})

    added = zeros(eltype(alltimes), size(alltimes)[1:2])
    N = length(alltimes[1, 1, :])
    for i=1:N
        added += alltimes[:, :, i]
    end
    
    return added ./ N
end

function faverage(output::FlexpartOutput)
    hasselection(output) && length(size(output.dataset)) == 3 || error("The dataset must be 3D")
    faverage(output.dataset)
end


function daily_average(alltimes::Union{Array{Float32, 3}, Array{Float64, 3}, Array{Real, 3}}, times::Vector)
    sdays = split_days(times)
    daily_av = zeros(eltype(alltimes), (size(alltimes)[1:2]..., length(sdays)))
    for (index, day_index) in enumerate(sdays)
        days = alltimes[:, :, day_index];
        daily_av[:, :, index] = faverage(days)
    end
    return daily_av, DateTime.(times[[s[1] for s in sdays]])
end

function daily_average(output::FlexpartOutput)
    hasselection(output) && length(size(output.dataset)) == 3 || error("The dataset must be 3D")
    daily_average(output.dataset, alldims(output)[:time])
end

# function add_time_average(file)
#     dataset = Flexpart.conc(file)
#     s = size(dataset)
#     new_dataset = zeros(s[1], s[2], s[3], s[5], s[6])
#     for height in 1:s[3], pointspec in 1:s[5], nageclass in 1:s[6]
#         new_dataset[:,:,height, pointspec, nageclass] = time_average(dataset[:,:,height, :, pointspec, nageclass])
#     end

#     attribs = Dict(
#         "units" => "ng m-3",
#         "long_name" => "time average conc"
#     )
#     nccreate(file, "time_av", 
#         "longitude", 
#         "latitude",
#         "height",
#         "pointspec",
#         "nageclass",
#         atts=attribs)

#     ncwrite(new_dataset, file, "time_av")
# end

# function add_daily_average(file)
#     name = "daily_av"
#     dataset = Flexpart.conc(file)
#     s = size(dataset)
#     times = times_dt(file)
#     ndays = split_days(times) |> length
#     new_dataset = zeros(s[1], s[2], s[3], s[5], s[6], ndays)

#     for height in 1:s[3], pointspec in 1:s[5], nageclass in 1:s[6]
#         new_dataset[:,:,height, pointspec, nageclass, :] = daily_average(dataset[:,:,height, :, pointspec, nageclass], times)
#     end

#     attribs = Dict(
#         "units" => "ng m-3",
#         "long_name" => "time average conc"
#     )

#     nccreate(file, name, 
#         "longitude", 
#         "latitude",
#         "height",
#         "pointspec",
#         "nageclass",
#         "ndays", ndays,
#         atts=attribs)

#     ncwrite(new_dataset, file, name)
# end

function write_daily_average!(output::FlexpartOutput; copy = true)
    name = NCDatasets.name(output.ncvar)*"_daily_av"
    filename = output.filename
    if copy
        newfn = split(basename(output.filename), ".")
        newfn = joinpath(dirname(output.filename), newfn[1] * "_daily_av" * "." * newfn[2])
        filename = cp(output.filename, newfn, force=true)
    end
    daily_ds, days = daily_average(output)

    attr = attrib(output.ncvar)
    toadd = completedim(output)
    # days_sec = Int32.(Dates.value.(days .- days[1]) .* 24 * 3600)
    copy || close(output.ncdataset)
    ds = NCDataset(filename, "a")
    # defDim(ds, "day", length(days))
    defVar(ds, "day", days, ("day",))

    defVar(ds,name,convert.(Float64, daily_ds),("lon","lat","day"), attrib = merge(symb2string.((attr, toadd))...))
    close(ds)
    filename
    # FlexpartOutput(filename)
end

function write_worst_day(output::FlexpartOutput; copy=true)
    (hasselection(output) && length(size(output.dataset))) == 3 || error("The dataset must be 3D")
    name = "worst_day"
    filename = output.filename
    if copy
        newfn = split(output.filename, ".")
        newfn = newfn[1] * "_worst_day" * "_copy." * newfn[2]
        filename = cp(output.filename, newfn, force=true)
    end
    dsworst, indworst = findworst_day(output.dataset)
    dayworst = output.ncdataset["day"][:][indworst]

    attr = attrib(output.ncvar)
    toadd = Dict("day" => Dates.format(dayworst, "yyyymmdd"))
    copy || close(output.ncdataset)
    ds = NCDataset(filename, "a")
    
    
    defVar(ds,name,convert.(Float64, dsworst),("lon","lat"), attrib = merge(symb2string.((attr, toadd))...))
    close(ds)
    FlexpartOutput(filename)
end

completedim(output::FlexpartOutput) = filter(e -> !(e.second isa Vector), output.selected)

symb2string(d::Dict) = Dict(String(k) => v for (k,v) in d)

function sum_abs(field)
    sum(abs, field)
end

function findworst_day(fields::AbstractArray)
    sums = [sum_abs(f) for f in eachslice(fields, dims=3)]
    _, ind = findmax(sums)
    fields[:, :, ind], ind
end

function worst_day(fields::AbstractArray)
    f, _ = findworst_day(fields)
    f
end

function start_dt(file)
    NCDataset(file, "r") do ds
        globatt = ds.attrib
        Dates.DateTime(globatt["ibdate"]*globatt["ibtime"], dateformat"yyyymmddHHMMSS")
    end
end

function end_dt(file)
    NCDataset(file, "r") do ds
        globatt = ds.attrib
        Dates.DateTime(globatt["iedate"]*globatt["ietime"], dateformat"yyyymmddHHMMSS")
    end
end

function split_days(times::Vector)
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

# function times_dt(file)::Vector{DateTime}
#     startdate = start_dt(file)

#     times = convert.(Int, getvar(file, "time") ./ 3600)

#     return [startdate + Dates.Hour(x) for x in times]
# end

function times_dt(file)::Vector{DateTime} 
    NCDataset(file, "r") do ds
        ds["time"][:]
    end
end

Base.close(output::FlexpartOutput) = close(output.ncdataset)