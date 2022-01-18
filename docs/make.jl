using Documenter, Flexpart

makedocs(
    sitename="Flexpart.jl docs",
    pages = [
        "Home" => "index.md",
        "Manual" => "man/guide.md",
        "Library" => [
            "Internals" => "lib/internals/flexpart.md"
        ],
    ],
    )