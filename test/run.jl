import Flexpart: FP_TESTS_DETER_INPUT, FP_TESTS_ENS_INPUT, default_run
using Flexpart
using Test
using Dates

default_run(tmpdir)