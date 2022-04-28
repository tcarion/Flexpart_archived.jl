function outer_vals(v::Vector{<:Real}, bounds)
    length(bounds) == 2 || error("bounds must contain 2 values")
    (bounds[1] < v[1] || bounds[2] > v[end]) && error("$bounds is outside of vector range")
    lower = v[findfirst(x -> x > bounds[1], v)-1]
    upper = v[findfirst(x -> x >= bounds[2], v)]
    lower, upper
end

function inner_vals(v::Vector{<:Real}, bounds)
    length(bounds) == 2 || error("bounds must contain 2 values")
    (bounds[1] < v[1] || bounds[2] > v[end]) && error("$bounds is outside of vector range")
    lower = v[findfirst(x -> x >= bounds[1], v)]
    upper = v[findfirst(x -> x > bounds[2], v)-1]
    lower, upper
end

function inner_area(area::Vector{<:Real}, gridres::Real)
    alons = -180.0:gridres:180.0 |> collect
    alats = -90.0:gridres:90.0 |> collect
    
    inlons = inner_vals(alons, (area[2], area[4]))
    inlats = inner_vals(alats, (area[3], area[1]))
    round.([inlats[2], inlons[1], inlats[1], inlons[2]], digits=6)
end

function outer_area(area::Vector{<:Real}, gridres::Real)
    alons = -180.0:gridres:180.0 |> collect
    alats = -90.0:gridres:90.0 |> collect
    
    inlons = outer_vals(alons, (area[2], area[4]))
    inlats = outer_vals(alats, (area[3], area[1]))
    round.([inlats[2], inlons[1], inlats[1], inlons[2]], digits=6)
end
 
round_area(area::Vector{<:Real}, mult=1) = return [ceil(area[1]*mult)/mult, floor(area[2]*mult)/mult, floor(area[3]*mult)/mult, ceil(area[4]*mult)/mult]

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

function copyall(src::AbstractString, dest::AbstractString)
    for el in readdir(src, join=true)
        cp(el, joinpath(dest, basename(el)))
    end
    changeperm(dest)
end

function changeperm(path)
    for (root, dirs, files) in walkdir(path)
        for dir in dirs
            chmod(joinpath(root, dir), 0o755)
        end
        for file in files
            chmod(joinpath(root, file), 0o644)
        end
    end
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

function writelines(io::IO, lines::Vector{<:String})
    for line in lines Base.write(io, line*"\n") end
end

function writelines(path::String, lines::Vector{<:String})
    (tmppath, tmpio) = mktemp()

    writelines(tmpio, lines)

    close(tmpio)
    dest = path

    mv(tmppath, dest, force=true)
end