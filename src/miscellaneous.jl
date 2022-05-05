function set_cmd_with_avs!(options::FlexpartOption, avs::Available)
    options["COMMAND"][:COMMAND][:IBDATE] = Dates.format(avs[1].time, "yyyymmdd")
    options["COMMAND"][:COMMAND][:IBTIME] = Dates.format(avs[1].time, "HHMMSS")
    options["COMMAND"][:COMMAND][:IEDATE] = Dates.format(avs[end].time, "yyyymmdd")
    options["COMMAND"][:COMMAND][:IETIME] = Dates.format(avs[end].time, "HHMMSS")
end

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