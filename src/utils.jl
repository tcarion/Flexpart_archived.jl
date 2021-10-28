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

