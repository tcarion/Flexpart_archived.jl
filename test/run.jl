using Flexpart: FP_TESTS_DETER_INPUT, FP_TESTS_ENS_INPUT
using Test
using Dates

tmpdir = FlexpartDir()
Flexpart.run(tmpdir)
Flexpart.run(tmpdir, log = true)

@test isfile(joinpath(tmpdir[:output], "output.log"))


function default_run(fpdir::FlexpartDir{Deterministic})
    fpdir[:input] = abspath(FP_TESTS_DETER_INPUT)
    avs = Available(fpdir)
    Flexpart.write(avs)
    options = FlexpartOption(fpdir)
    gribpath = joinpath(avs[1].dirpath, avs[1].filename)
    options["COMMAND"][:COMMAND][:IBDATE] = Dates.format(avs[1].time, "yyyymmdd")
    options["COMMAND"][:COMMAND][:IBTIME] = Dates.format(avs[1].time, "HHMMSS")
    options["COMMAND"][:COMMAND][:IEDATE] = Dates.format(avs[end].time, "yyyymmdd")
    options["COMMAND"][:COMMAND][:IETIME] = Dates.format(avs[end].time, "HHMMSS")
    options["RELEASES"][:RELEASE][:IDATE1] = Dates.format(avs[1].time, "yyyymmdd")
    options["RELEASES"][:RELEASE][:ITIME1] = Dates.format(avs[1].time, "HHMMSS")
    options["RELEASES"][:RELEASE][:IDATE2] = Dates.format(avs[1].time, "yyyymmdd")
    options["RELEASES"][:RELEASE][:ITIME2] = Dates.format(avs[1].time + Dates.Minute(30), "HHMMSS")
    options["RELEASES"][:RELEASE][:LAT1] = 50.5
    options["RELEASES"][:RELEASE][:LAT2] = 50.5
    options["RELEASES"][:RELEASE][:LON1] = 5.0
    options["RELEASES"][:RELEASE][:LON2] = 5.0
    gridres, _ = Flexpart.grib_resolution(gribpath)
    outgrid = Flexpart.area2outgrid(fpdir, gridres)
    merge!(options["OUTGRID"][:OUTGRID], outgrid)
    Flexpart.write(avs)
    Flexpart.write(options)
    Flexpart.run(fpdir)
end