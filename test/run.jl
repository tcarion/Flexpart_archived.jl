import Flexpart: FP_TESTS_DETER_INPUT, FP_TESTS_ENS_INPUT, default_run
using Flexpart
using Test
using Dates

tmpdir = FlexpartDir()
default_run(tmpdir)