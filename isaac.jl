export Isaac64, rand, sysRandomSeed
type IsaacState
    a::Uint64
    b::Uint64
    aa::Uint64
    bb::Uint64
    cc::Uint64
    RANDSIZL::Int
    RANDSIZ::Int
end
type Isaac64
    state::IsaacState
    randrsl::Vector{Uint64}
    mm ::Vector{Uint64}
    randcnt::Int
end
function Isaac64(seed::Vector{Uint64}=Uint64[])
    state,randrsl, mm = main(seed)
    return Isaac64(state, randrsl, mm, state.RANDSIZ+1)
end
function Isaac64(state::IsaacState, randrsl::Vector{Uint64}, mm::Vector{Uint64})
    return Isaac64(state, randrsl, mm, state.RANDSIZ+1)
end

function rand{T<:Union(Uint8,Uint16, Uint32, Uint64, Int8, Int16, Int32, Int64)}(rng::Isaac64, t::Type{T})
    return convert(t, rand(rng))
end
function rand(rng::Isaac64, t::Type{Float64})
    return float64(string("0.", string(int128(rand(rng)))))
end
function rand(rng::Isaac64)
    if rng.randcnt != 1
        return rng.randrsl[rng.randcnt -=1]
    else
        rng.randcnt=rng.state.RANDSIZ
        isaac64rng(rng.state, rng.randrsl, rng.mm)
        return rng.randrsl[rng.randcnt]
    end
end
function ind(s::IsaacState, mm, x)
    return mm[1 + (x & ((s.RANDSIZ-1)<<3))>>3]
end

function rngstep(s::IsaacState, randrsl, mm, a_mix, m1, m2, r, i)
    x = mm[m1 + i]
    s.a = a_mix + mm[m2 + i]
    mm[m1 + i] = y = ind(s, mm, x) + s.a + s.b
    randrsl[r + i] = s.b = ind(s, mm, y >> s.RANDSIZL) + x
end
function isaac64rng(rng::Isaac64)
    isaac64rng(rng.state, rng.randrsl, rng.mm)
end
function isaac64rng(s::IsaacState, randrsl, mm)
    s.a = s.aa
    s.cc += 1
    s.b = s.bb + s.cc
    m1 = r = 0
    mid = m2 = s.RANDSIZ >> 1
    for i = 1:4:mid-2
        rngstep(s, randrsl, mm, ~(s.a $ (s.a << 21)), m1, m2, r, i)
        rngstep(s, randrsl, mm,   s.a $ (s.a >> 5),   m1, m2, r, i + 1)
        rngstep(s, randrsl, mm,   s.a $ (s.a << 12),  m1, m2, r, i + 2)
        rngstep(s, randrsl, mm,   s.a $ (s.a >> 33),  m1, m2, r, i + 3)
    end
    m2 = 0
    r = m1 = s.RANDSIZ >> 1
    for i = 1:4:mid-2
        rngstep(s, randrsl, mm, ~(s.a $ (s.a << 21)), m1, m2, r, i)
        rngstep(s, randrsl, mm,   s.a $ (s.a >> 5),   m1, m2, r, i + 1)
        rngstep(s, randrsl, mm,   s.a $ (s.a << 12),  m1, m2, r, i + 2)
        rngstep(s, randrsl, mm,   s.a $ (s.a >> 33),  m1, m2, r, i + 3)
    end
    s.bb = s.b
    s.aa = s.a;
end

macro mix()
    quote
        a -= e; f $= h >> 9;  h += a
        b -= f; g $= a << 9;  a += b
        c -= g; h $= b >> 23; b += c
        d -= h; a $= c << 15; c += d
        e -= a; b $= d >> 14; d += e
        f -= b; c $= e << 20; e += f
        g -= c; d $= f >> 17; f += g
        h -= d; e $= g << 14; g += h
    end
end
function randinit(randrsl, mm, RANDSIZL, RANDSIZ, flag=false)
    a = b = c = d = e = f = g = h = 0x9e3779b97f4a7c13
    for i = 1:4
        @mix
    end
    for i = 1:8:RANDSIZ
        if flag
            a += mm[i  ]; b += mm[i+1]; c += mm[i+2]; d += mm[i+3]
            e += mm[i+4]; f += mm[i+5]; g += mm[i+6]; h += mm[i+7]
        end
        @mix
            mm[i  ] = a; mm[i+1] = b; mm[i+2] = c; mm[i+3] = d
            mm[i+4] = e; mm[i+5] = f; mm[i+6] = g; mm[i+7] = h
    end
    if flag
        for i = 1:8:RANDSIZ
              a += mm[i  ]; b += mm[i+1]; c += mm[i+2]; d += mm[i+3]
              e += mm[i+4]; f += mm[i+5]; g += mm[i+6]; h += mm[i+7]
            @mix
              mm[i  ] = a; mm[i+1] = b; mm[i+2] = c; mm[i+3] = d
              mm[i+4] = e; mm[i+5] = f; mm[i+6] = g; mm[i+7] = h
        end
    end
    z = 0x0000000000000000
    s2 = IsaacState(z, z, z, z, z, RANDSIZL, RANDSIZ)
    isaac64rng(s2, randrsl, mm)
    return s2
end
function main(randrsl::Vector{Uint64}=Uint64[])
    RANDSIZL = 8
    RANDSIZ = length(randrsl)
    if RANDSIZ == 0
        RANDSIZ = 256
        resize!(randrsl, RANDSIZ)
        fill!(randrsl, uint64(0))
    elseif RANDSIZ % 8 != 0
        error("dimension of seeding array must be a factor of 8")
    end
    mm = zeros(Uint64, RANDSIZ)
    s = randinit(randrsl, mm, RANDSIZL, RANDSIZ, true)
    for i = 1:2
        isaac64rng(s, randrsl, mm)
    end
    return s, randrsl, mm
end

function sysRandomSeed{T<:Number}(size=256, t::Type{T}=Uint64, sysrand_path="/dev/urandom")
    seed_array = resize!(t[], size)
    f=open(sysrand_path)
    read!(f, seed_array)
    close(f)
    return seed_array
end

