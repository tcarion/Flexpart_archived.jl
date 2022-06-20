function set_cmd_with_dates!(options::FlexpartOption, start::DateTime, stop::DateTime)
    options["COMMAND"][:COMMAND][:IBDATE] = Dates.format(start, "yyyymmdd")
    options["COMMAND"][:COMMAND][:IBTIME] = Dates.format(start, "HHMMSS")
    options["COMMAND"][:COMMAND][:IEDATE] = Dates.format(stop, "yyyymmdd")
    options["COMMAND"][:COMMAND][:IETIME] = Dates.format(stop, "HHMMSS")
end

set_cmd_with_avs!(options::FlexpartOption, avs::Available) = set_cmd_with_dates!(options::FlexpartOption, avs[1].time, avs[end].time)

function set_release_at_start!(options::FlexpartOption, avs::Available, duration::Dates.AbstractTime)
    options["RELEASES"][:RELEASE][:IDATE1] = Dates.format(avs[1].time, "yyyymmdd")
    options["RELEASES"][:RELEASE][:ITIME1] = Dates.format(avs[1].time, "HHMMSS")
    options["RELEASES"][:RELEASE][:IDATE2] = Dates.format(avs[1].time, "yyyymmdd")
    options["RELEASES"][:RELEASE][:ITIME2] = Dates.format(avs[1].time + duration, "HHMMSS")
end

function set_point_release!(options::FlexpartOption, lon, lat)
    options["RELEASES"][:RELEASE][:LAT1] = lat
    options["RELEASES"][:RELEASE][:LAT2] = lat
    options["RELEASES"][:RELEASE][:LON1] = lon
    options["RELEASES"][:RELEASE][:LON2] = lon 
end

function area2outgrid(area::Vector{<:Real}, gridres::Real = 0.01; nested = false)
    outlon0 = area[2]
    outlat0 = area[3]
    Δlon = area[4] - outlon0
    Δlat = area[1] - outlat0
    Δlon, Δlat = round.([Δlon, Δlat], digits = 5)
    (numxgrid, numygrid) = try
        convert(Int, round(Δlon / gridres)), convert(Int, round(Δlat / gridres))
    catch
        error("gridres must divide area")
    end
    dxout = gridres
    dyout = gridres
    res = Dict(
        :OUTLON0 => outlon0, :OUTLAT0 => outlat0, :NUMXGRID => numxgrid, :NUMYGRID => numygrid, :DXOUT => dxout, :DYOUT => dyout,
    )
    nested ? Dict(
        String(k) * 'N' |> Symbol => v for (k, v) in res
    ) : res
end

function area2outgrid(fpdir::FlexpartDir, gridres::Real; nested = false)
    firstinput = readdir(fpdir[:input], join = true)[1]
    area = grib_area(firstinput)

    area2outgrid(area, gridres; nested)
end

function remove_unused_species!(fpoptions::FlexpartOption)
    nspec = parse(Int, fpoptions["RELEASES"][:RELEASES_CTRL][:SPECNUM_REL].value)
    for (k, v) in fpoptions.options
        try
            specnum = parse(Int, k[end-2:end])
            if !(nspec == specnum)
                pop!(fpoptions.options, k)
            end
        catch
        end
    end
end