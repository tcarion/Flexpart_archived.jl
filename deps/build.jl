using Pkg.Artifacts
using PyCall
using FlexExtract_jll

const PIP_PACKAGES = ["eccodes", "genshi", "numpy", "cdsapi", "ecmwf-api-client"]
const PIP_PACKAGES_OPTIONAL = ["polytope-client"]

# Install the python dependencies for flex_extract
# See https://discourse.julialang.org/t/pycall-pre-installing-a-python-package-required-by-a-julia-package/3316/16
sys = pyimport("sys")
subprocess = pyimport("subprocess")
subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "--upgrade", PIP_PACKAGES...])

try
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "--upgrade", PIP_PACKAGES_OPTIONAL...])
catch
    @warn "Polytope couldn't be installed. Only requests from ecmwf normal client is available."
end

# run(`$(PyCall.python) $(install_pyscript) $args`)



