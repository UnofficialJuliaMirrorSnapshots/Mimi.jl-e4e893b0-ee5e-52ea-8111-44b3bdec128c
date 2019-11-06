#
# Types supporting parameterized Timestep and Clock objects
#

abstract type AbstractTimestep <: MimiStruct end

struct FixedTimestep{FIRST, STEP, LAST} <: AbstractTimestep
    t::Int
end

struct VariableTimestep{TIMES} <: AbstractTimestep
    t::Int
    current::Int

    function VariableTimestep{TIMES}(t::Int = 1) where {TIMES}
        # The special case below handles when functions like next_step step beyond
        # the end of the TIMES array.  The assumption is that the length of this
        # last timestep, starting at TIMES[end], is 1.
        current::Int = t > length(TIMES) ? TIMES[end] + 1 : TIMES[t]

        return new(t, current)
    end
end

struct TimestepValue{T}
    value::T
    offset::Int

    function TimestepValue(v::T; offset::Int = 0) where T
        return new{T}(v, offset)
    end
end
  
struct TimestepIndex
    index::Int
end

mutable struct Clock{T <: AbstractTimestep} <: MimiStruct
	ts::T

	function Clock{T}(FIRST::Int, STEP::Int, LAST::Int) where T
		return new(FixedTimestep{FIRST, STEP, LAST}(1))
    end

    function Clock{T}(TIMES::NTuple{N, Int} where N) where T
        return new(VariableTimestep{TIMES}())
    end
end

mutable struct TimestepArray{T_TS <: AbstractTimestep, T, N, ti} <: MimiStruct
	data::Array{T, N}

    function TimestepArray{T_TS, T, N, ti}(d::Array{T, N}) where {T_TS, T, N, ti}
		return new(d)
	end

    function TimestepArray{T_TS, T, N, ti}(lengths::Int...) where {T_TS, T, N, ti}
		return new(Array{T, N}(undef, lengths...))
	end
end

# Since these are the most common cases, we define methods (in time.jl)
# specific to these type aliases, avoiding some of the inefficiencies
# associated with an arbitrary number of dimensions.
const TimestepMatrix{T_TS, T, ti} = TimestepArray{T_TS, T, 2, ti}
const TimestepVector{T_TS, T} = TimestepArray{T_TS, T, 1, 1}
