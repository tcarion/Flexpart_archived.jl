module FpOutput

abstract type AbstractFpDataset{T, N} <: AbstractArray{T, N} end
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
    # ncdataset::Union{NCDatasets.NCDataset, Nothing}
    # dataset::Union{Array{Real}, Nothing}
    # ncvar::Union{NCDatasets.CFVariable, Nothing}
    # # remdim::Union{NamedTuple, Nothing}
    # selected::Union{Dict{Symbol, Any}, Nothing}
    metadata::MetaData
end


struct FpDataset{T, N} <: AbstractFpDataset{T, N}
    fpoutput::FlexpartOutput
    dataset::Array{T, N}
    varname::String
    selected::NamedTuple
end

# output_dir(fpdir::FlexpartDir) = joinpath(fpdir.path, fpdir[:output])
function FlexpartOutput(filename::String)
    filename = abspath(filename)
    lons, lats = mesh(filename)
    FlexpartOutput(filename, lons, lats, MetaData(filename))
end

FlexpartOutput(fpdir::FlexpartDir, name::String) = FlexpartOutput(joinpath(getdir(fpdir, :output), name))
FlexpartOutput(path::String, name::String) = FlexpartOutput(FlexpartDir(path), name)

function ncf_files(fpdir::FlexpartDir; onlynested=false)
    out_files = readdir(getdir(fpdir, :output))
    f = onlynested ? x -> occursin(".nc", x) && occursin("nest", x) :  x ->  occursin(".nc", x)
    files = filter(f, out_files)
    [joinpath(getdir(fpdir, :output), x) |> abspath for x in files]
end

ncf_files(path::String; onlynested=false) = ncf_files(FlexpartDir(path), onlynested=onlynested)


function MetaData(filename::String)
    NCDataset(filename, "r") do ds
        rellats, rellons = relloc(filename)
        parts = ds["RELPART"]
        MetaData(start_dt(filename), end_dt(filename), times_dt(filename), sum(parts), rellons, rellats)
    end
end

function opends(f::Function, args...)
    NCDataset(args[1], "r") do ds
        f(ds)
    end
end
is2d(ncvar::NCDatasets.CFVariable) = ncvar[:] isa Matrix

Base.size(fpds::AbstractFpDataset) = size(fpds.dataset)
Base.getindex(fpds::AbstractFpDataset, args...) = getindex(fpds.dataset, args...)
Base.setindex!(fpds::AbstractFpDataset, args...) = setindex!(fpds.dataset, args...)
function Base.show(io::IO, m::MIME"text/plain", fpds::AbstractFpDataset{T, N}) where {T, N} 
    println(io, "Flexpart Output with variable: ", fpds.varname)
    println(io, "Selected dimensions: ", fpds.selected)
    print(io, "Dataset: ", typeof(fpds.dataset))
end
function Base.:+(fpds1::AbstractFpDataset{T, N}, fpds2::AbstractFpDataset{T, N}) where {T, N}
    addable(fpds1, fpds2)
    FpDataset(fpds1.fpoutput, fpds1.dataset + fpds2.dataset, fpds1.varname*"_added", fpds1.selected)
end
function Base.:-(fpds1::AbstractFpDataset{T, N}, fpds2::AbstractFpDataset{T, N}) where {T, N}
    addable(fpds1, fpds2)
    FpDataset(fpds1.fpoutput, fpds1.dataset - fpds2.dataset, fpds1.varname*"_diff", fpds1.selected)
end

function addable(fpds1::AbstractFpDataset{T, N}, fpds2::AbstractFpDataset{T, N}) where {T, N}
    fpds1.varname == fpds2.varname || error("Selected variables must be equal")
    Flexpart.completedim(fpds1) |> keys == Flexpart.completedim(fpds2) |> keys || error("Same dimensions must be selected")
    true
end

function variables(ncdataset::NCDataset)
    variables = keys(ncdataset)
end

function variables2d(ncdataset::NCDataset)
    vars = variables(ncdataset)
    lons, lats = mesh(ncdataset)
    inds = findall( x ->
        try 
            size(ncdataset[x])[1:2] == (length(lons), length(lats))
        catch
            false
        end,
        vars
        )
    vars[inds]
end

function variables(fpoutput::FlexpartOutput)
    opends(fpoutput.filename) do ds
        variables(ds)
    end
end
function variables2d(fpoutput::FlexpartOutput)
    opends(fpoutput.filename) do ds
        variables2d(ds)
    end
end

function getvar(fpoutput::FlexpartOutput, varname)
    opends(fpoutput.filename) do ds
        ds[varname][:]
    end
end

function remdim(output::FlexpartOutput, varname::String)
    opends(output.filename) do ds
        ncvar = ds[varname]
        remdim(ncvar)
    end
end
function remdim(ncvar::NCDatasets.CFVariable)
    names = NCDatasets.dimnames(ncvar)
    sizes = NCDatasets.dimsize(ncvar)
    NamedTuple{Symbol.(names[3:end])}(sizes)
end

attrib(ds::NCDatasets.NCDataset) = Dict(ds.attrib)
attrib(ds::NCDatasets.CFVariable) = push!(Dict(ds.attrib), "name" => NCDatasets.name(ds))
function attrib(fpoutput::FlexpartOutput)
    opends(fpoutput.filename) do ds
        attrib(ds)
    end
end
function attrib(fpoutput::FlexpartOutput, varname::String)
    opends(fpoutput.filename) do ds
        attrib(ds[varname])
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
function alldims(fpoutput::FlexpartOutput, varname::String)
    opends(fpoutput.filename) do ds
        alldims(ds, ds[varname])
    end
end

function getspatial(ncds::NCDataset, ncvar::NCDatasets.CFVariable, dims::NamedTuple = NamedTuple())
    lons, lats = mesh(ncds)
    try 
        @assert size(ncvar)[1:2] == (length(lons), length(lats))
    catch
        throw(ArgumentError("The selected field is not a spatial field"))
    end
    rd = remdim(ncvar)
    indices = []
    for k in keys(rd)
        if k in keys(dims)
            push!(indices, dims[k])
        else
            push!(indices, :)
        end
    end
    nt = NamedTuple{keys(rd)}(indices)
    ncvar[:,:,nt...]
end

function select(fpoutput::FlexpartOutput, varname::String, dims::NamedTuple = NamedTuple())
    opends(fpoutput.filename) do ds
        field = getspatial(ds, ds[varname], dims)
        FpDataset(fpoutput, field, varname, dims)
    end
end

function select(fpoutput::FlexpartOutput, varname::String, dims::Dict) :: FpDataset
    adims = alldims(fpoutput, varname)
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
            typev = typeof(v)
            typed = typeof(d)
            typev == typed ?
                v : 
                parse_date([(v, "yyyymmddTHHMMSS"), (v[1:19], "yyyy-mm-ddTHH:MM:SS")])
        catch
            error("Wrong type to be selected")
        end

        inds = try
            findfirst(x -> x == v, adims[k])
        catch
            error("Some selected variables don't exist")
        end
        push!(indices, inds)
    end
    ndims = NamedTuple{Tuple(keys(dims) |> collect)}(indices)
    select(fpoutput, varname, ndims)
end

function parse_date(args::Vector{Tuple{String, String}})
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

function selected(fpds::FpDataset)
    sel = fpds.selected
    adims = alldims(fpds.fpoutput, fpds.varname)

    Dict(k => adims[k][v] for (k, v) in zip(keys(sel), sel))
end

mesh(fpoutput::FlexpartOutput) = mesh(fpoutput.filename)
function mesh(file)
    opends(file) do ds
        mesh(ds)
    end
end

function mesh(ncdataset::NCDataset)
    lon = ncdataset["longitude"]; lat = ncdataset["latitude"]
    lon[:], lat[:]
end

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
        rellons, rellats
    end
end

function faverage(alltimes::Array{<:Real, 3})

    added = zeros(eltype(alltimes), size(alltimes)[1:2])
    N = length(alltimes[1, 1, :])
    for i=1:N
        added += alltimes[:, :, i]
    end
    
    return added ./ N
end

# function faverage(output::FlexpartOutput)
#     hasselection(output) && length(size(output.dataset)) == 3 || error("The dataset must be 3D")
#     faverage(output.dataset)
# end


function daily_average(alltimes::Array{<:Real, 3}, times::Vector)
    sdays = split_days(times)
    daily_av = zeros(eltype(alltimes), (size(alltimes)[1:2]..., length(sdays)))
    for (index, day_index) in enumerate(sdays)
        days = alltimes[:, :, day_index];
        daily_av[:, :, index] = faverage(days)
    end
    return daily_av
end

function daily_average(fpds::FpDataset)
    fpds.dataset isa Array{T, 3} where T || error("The dataset must be 3D")
    #TODO: throw error if selected is not time
    daily_average(fpds.dataset, alldims(fpds.fpoutput, fpds.varname)[:time])
end

completedim(fpds::FpDataset) = filter(e -> !(e.second isa Vector), selected(fpds))

# function write_daily_average(fpds::FpDataset; copy = true)
#     name = fpds.varname*"_daily_av"
#     filename = fpds.fpoutput.filename
#     if copy
#         newfn = split(basename(filename), ".")
#         newfn = joinpath(dirname(filename), newfn[1] * "_daily_av" * "." * newfn[2])
#         filename = cp(filename, newfn, force=true)
#     end
#     daily_ds, days = daily_average(fpds)

#     attr = attrib(fpds.fpoutput, fpds.varname)
#     toadd = completedim(fpds)

#     NCDataset(filename, "a") do ds
#         defVar(ds, "day", days, ("day",))
    
#         defVar(ds,name,convert.(Float64, daily_ds),("lon","lat","day"), attrib = merge(symb2string.((attr, toadd))...))
#     end
#     filename
# end

function write_daily_average(fpds::FpDataset; copy = true)
    name = fpds.varname*"_daily_av"
    filename = fpds.fpoutput.filename
    if copy
        newfn = split(basename(filename), ".")
        newfn = joinpath(dirname(filename), newfn[1] * "_daily_av" * "." * newfn[2])
        filename = cp(filename, newfn, force=true)
    end

    times = alldims(fpds.fpoutput, fpds.varname)[:time]
    s = size(fpds)
    s = (s[1:3]..., s[5:end]...)
    sdays = split_days(times)
    ndays = sdays|> length
    days = DateTime.(times[[s[1] for s in sdays]])
    new_dataset = zeros(s..., ndays)
    for height in 1:s[3], pointspec in 1:s[4], nageclass in 1:s[5]
        new_dataset[:,:,height, pointspec, nageclass, :] = daily_average(fpds[:,:,height, :, pointspec, nageclass], times)
    end


    attr = attrib(fpds.fpoutput, fpds.varname)
    toadd = completedim(fpds)

    NCDataset(filename, "a") do ds
        defVar(ds, "day", days, ("day",))
    
        defVar(ds,name,convert.(Float64, new_dataset),("lon","lat", "height", "pointspec", "nageclass", "day"), attrib = merge(symb2string.((attr, toadd))...))
    end
    filename
end

# macro

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

function times_dt(file)::Vector{DateTime} 
    NCDataset(file, "r") do ds
        ds["time"][:]
    end
end

end