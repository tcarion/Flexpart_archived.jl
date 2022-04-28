import Flexpart: FP_TESTS_DETER_INPUT, FP_TESTS_ENS_INPUT, default_run
using Flexpart
using Test
using Dates

tmpdir = FlexpartDir()
Flexpart.run(tmpdir)
Flexpart.run(tmpdir, log = true)

@test isfile(joinpath(tmpdir[:output], "output.log"))

default_run(tmpdir)