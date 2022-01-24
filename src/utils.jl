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

function copyall(src::String, dest::String)
    for el in readdir(src, join=true)
        cp(el, joinpath(dest, basename(el)))
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