using GRIB

function grib_area(file::String) :: Vector{<:Float32}
    GribFile(file) do reader
        m = Message(reader)
        lons, lats = data(m)
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
        return convert.(Float32, [maximum(lats), min_lon, minimum(lats), max_lon])
    end
end

function get_key_values(file::String, key::String)
    key_values = Vector()
    GribFile(file) do reader
        for msg in reader
            push!(key_values, string(msg[key]))
        end
    end
    return unique(key_values)
end

function get_keys(file::String)::Vector{String}
    keylist = Vector{String}()
    GribFile(file) do reader
        for msg in reader
            for key in keys(msg)
                push!(keylist, key)
            end
        end
    end
    keylist |> unique
end