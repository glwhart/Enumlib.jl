"""
    InequivalentCount{D}

Structured return of `count_inequivalent(...; breakdown = true)`. Total count plus per-supercell breakdown so the user can see "where my structures come from."

Fields:
- `total::BigInt` — sum across the request.
- `by_volume::Vector{Tuple{Int, BigInt}}` — `(n, count_at_n)` pairs, in volume order.
- `by_concentration::Vector{Tuple{Concentration, BigInt}}` — populated when `concentration` was a `ConcentrationRange`; one entry per partition. Empty otherwise.
- `by_hnf::Vector{Tuple{HNF{D}, BigInt}}` — per-HNF count (one entry per symmetry-inequivalent HNF in the request). Useful for diagnosing which HNFs dominate the count.

`enumerate_hnfs(...)` already returns one HNF per symmetry class, so the flat per-HNF list serves the same role a dedicated `HNFClass` type would. No quotient wrapper is needed today.
"""
struct InequivalentCount{D}
    total::BigInt
    by_volume::Vector{Tuple{Int, BigInt}}
    by_concentration::Vector{Tuple{Concentration, BigInt}}
    by_hnf::Vector{Tuple{HNF{D}, BigInt}}
end

Base.:(==)(a::InequivalentCount{D}, b::InequivalentCount{D}) where D =
    a.total == b.total &&
    a.by_volume == b.by_volume &&
    a.by_concentration == b.by_concentration &&
    a.by_hnf == b.by_hnf

function Base.show(io::IO, ::MIME"text/plain", c::InequivalentCount{D}) where D
    println(io, "InequivalentCount{$D}: total = $(c.total)")
    if !isempty(c.by_volume)
        println(io, "  by_volume:")
        for (n, count) in c.by_volume
            println(io, "    n = $n: $count")
        end
    end
    if !isempty(c.by_concentration)
        println(io, "  by_concentration: $(length(c.by_concentration)) entries")
    end
    if !isempty(c.by_hnf)
        print(io, "  by_hnf: $(length(c.by_hnf)) HNFs")
    end
end
