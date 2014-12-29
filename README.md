This is a port of ISAAC a fast CSPRNG from C, written by Bob Jenkins - his site and original code may be found here http://burtleburtle.net/bob/rand/isaacafa.html.
Usage:

``julia>rng = Isaac64(seed)``

Will create an instance of Isaac64, note it does not seed itself! If a seed is not specified it will seed with 0's.

``julia>seed=sysRandomSeed()``

Will return an 256 long array of UInt64 values - On linux this should work by default (reading from "/dev/urandom"), specify `sysrand_path` to read from a different location.

``julia>rand(rng)``

returns a single Uint64 value

``julia>rand(rng, T)``

returns a single value of type T
