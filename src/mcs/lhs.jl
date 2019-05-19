# Python version created in 2012.
# Ported to julia in January, 2018.
#
# Author: Rich Plevin
#
# Copyright (c) 2012-2018. The Regents of the University of California (Regents)
# and Richard Plevin. See the file COPYRIGHT.txt for details.
#
# Implements the Latin Hypercube Sampling technique as described by Iman and Conover, 1982,
# including correlation control both for no correlation or for a specified rank correlation
# matrix for the sampled parameters. Original python version was heavily modified from
# http://nullege.com/codes/show/src@m@o@model-builder-HEAD@Bayes@lhs.py
#
import StatsBase
using Statistics
using LinearAlgebra

# Defines a target rank correlation to establish between the two named random vars.
const CorrelationSpec = Tuple{Symbol, Symbol, Float64}

mutable struct LHSData <: AbstractSimulationData
    corrlist::Vector{CorrelationSpec}

    function LHSData(;corrlist::Vector{CorrelationSpec}=CorrelationSpec[])
        new(corrlist)
    end
end

const LatinHypercubeSimulation = Simulation{LHSData}

function Base.show(data::LHSData)
    Mimi.print_nonempty("corrlist", data.corrlist)
end

function sample!(sim::LatinHypercubeSimulation, samplesize::Int)
    sim.trials = samplesize
    corrmatrix = correlation_matrix(sim)
    lhs!(sim, corrmatrix=corrmatrix)
end

"""
    rank_corr_coef(m::Matrix{Float64})

Take a 2-D array of values and produce a array of rank correlation
coefficients representing the rank correlations pairs of columns.
"""
function rank_corr_coef(m::Matrix{Float64})
    cols = size(m, 2)
    corrCoef = Matrix(1.0I, cols, cols)    # identity matrix

    for i in 1:cols
        for j in (i + 1):cols
            corr = corspearman(m[:, i], m[:, j])
            corrCoef[i, j] = corrCoef[j, i] = corr
        end
    end

    return corrCoef
end

"""
    _gen_rank_values(params::Int, trials::Int, corrmatrix::Matrix{Float64})

Generate a data set of 'trials' ranks for 'params'
parameters that obey the given correlation matrix.

params: number of parameters.
trials: number of trials.
corrmatrix: rank correlation matrix for parameters.
corrmatrix[i,j] denotes the rank correlation between parameters
i and j.

Output is a Matrix with 'trials' rows and 'params' columns.
The i'th column represents the ranks for the i'th parameter.
"""
function _gen_rank_values(params::Int, trials::Int, corrmatrix::Matrix{Float64})
    # Create van der Waarden scores
    strata = collect(1.0:trials) / (trials + 1)
    vdwScores = quantile.(Normal(), strata)

    S = zeros(trials, params)
    for i in 1:params
        shuffle!(vdwScores)
        S[:, i] = vdwScores
    end

    P = Matrix(cholesky(corrmatrix, Val(false)).L)
    E = rank_corr_coef(S)
    Q = Matrix(cholesky(E, Val(false)).L)
    final = (S * inv(Q)') * P'

    ranks = zeros(Int, trials, params)
    for i in 1:params
        ranks[:, i] = ordinalrank(final[:, i])
    end

    return ranks
end

"""
    _get_percentiles(trials::Int)

Generate a list of 'trials' values, one from each of 'trials' equal-size
segments from a uniform distribution. These are used with an RV's ppf
(percent point function = inverse cumulative function) to retrieve the
values for that RV at the corresponding percentiles.
"""
function _get_percentiles(trials::Int)
    segmentSize = 1.0 / trials
    points = rand(Uniform(), trials) * segmentSize + collect(0:trials-1) * segmentSize
    return points
end

"""
    lhs(rvlist::Vector{RandomVariable}, trials::Int; corrmatrix::Union{Matrix{Float64},Nothing}=nothing, asDataFrame::Bool=true)
             
Produce an array or DataFrame of 'trials' rows of values for the given parameter
list, respecting the correlation matrix 'corrmatrix' if one is specified, using Latin
Hypercube (stratified) sampling.

The values in the i'th column are drawn from the ppf function of the i'th parameter
from rvlist, and each columns i and j are rank correlated according to corrmatrix[i,j].

rvlist: (list of rv-like objects representing parameters) Only requirement
       on parameter objects is that they must implement the ppf function.

trials: (int) number of trials to generate for each parameter.

corrmatrix: a numpy matrix representing the correlation between the parameters.
       corrmatrix[i,j] should give the correlation between the i'th and j'th
       entries of rvlist.

columns: (None or list(str)) Column names to use to return a DataFrame.

skip: (list of params)) Parameters to process later because they are
       dependent on other parameter values (e.g., they're "linked"). These
       cannot be correlated.

Returns DataFrame with `trials` rows of values for the `rvlist`.
"""
function lhs(rvlist::Vector{RandomVariable}, trials::Int; 
             corrmatrix::Union{Matrix{Float64},Nothing}=nothing,
             asDataFrame::Bool=true)

    num_rvs = length(rvlist)             
    ranks = corrmatrix === nothing ? nothing : _gen_rank_values(num_rvs, trials, corrmatrix)

    samples = zeros(trials, num_rvs)

    for (i, rv) in enumerate(rvlist)
        values = quantile.(Ref(rv.dist), _get_percentiles(trials))  # extract values from the RV for these percentiles

        if corrmatrix === nothing
            shuffle!(values)           # randomize the stratified samples
        else
            indices = ranks[:, i]
            values = values[indices]   # reorder to respect correlations
        end

        samples[:, i] = values
    end

    return asDataFrame ? DataFrame(samples, map(rv->rv.name, rvlist)) : samples
end

function lhs(sim::LatinHypercubeSimulation; 
             corrmatrix::Union{Matrix{Float64},Nothing}=nothing,
             asDataFrame::Bool=true)
    rvlist = collect(values(sim.rvdict))
    lhs(rvlist, sim.trials, corrmatrix=corrmatrix, asDataFrame=asDataFrame)
end

function lhs!(sim::LatinHypercubeSimulation; corrmatrix::Union{Matrix{Float64},Nothing}=nothing)
    # TBD: verify that any correlated values are actual distributions, not stored vectors?

    rvdict = sim.rvdict

    samples = lhs(sim, corrmatrix=corrmatrix, asDataFrame=false)

    for (i, rv) in enumerate(values(rvdict))
        name = rv.name
        values = samples[:, i]
        rvdict[name] = RandomVariable(name, SampleStore(values))
    end
    return nothing
end

# TBD: handle this outside lhs since it applies to any linked variables (or drop support for this...)
"""
    lhs_amend!(df::DataFrame, rvlist::Vector{RandomVariable}, trials::Int)

Amend the DataFrame with LHS data by adding columns for the given parameters.
This allows "linked" parameters to refer to the values of other parameters.

df: Generated by prior call to LHS or something similar.
rvlist: The random variables to add to the df
trials: the number of trials to generate for each parameter
"""
function lhs_amend!(df::DataFrame, rvlist::Vector{RandomVariable}, trials::Int, 
                    simtype::T) where T <: AbstractSimulationData
    for rv in rvlist
        if T == LatinHypercubeSimulation
            values = quantile.(rv.dist, _get_percentiles(trials))  # extract values from the RV for these percentiles
            shuffle!(values)                                       # randomize the stratified samples
        
        elseif T == MonteCarloSimulation
            values = rv.dist.rand(trials)
        end

        df[rv.name] = values
    end
    return nothing
end

"""
    correlation_matrix(sim::LatinHypercubeSimulation)

Return a Matrix holding the correlations between random variables
as indicated in the Simulation, or nothing if no correlations
have been defined.

TBD: if needed, compute correlation matrix only for correlated
     RVs, leaving all uncorrelated RVs alone.
"""
function correlation_matrix(sim::LatinHypercubeSimulation)
    if length(sim.data.corrlist) == 0
        return nothing
    end

    rvdict = sim.rvdict

    # create a mapping of names to RV position in list
    names = Dict([(rv.name, i) for (i, rv) in enumerate(values(rvdict))])

    count = length(rvdict)
    corrmatrix = Matrix(1.0I, count, count)

    for corr in sim.data.corrlist
        n1 = corr[1]
        n2 = corr[2]

        # We don't support correlation between stored samples
        # if rvdict[n1].dist isa SampleStore || rvdict[n2].dist isa SampleStore
        #     error("Correlations with SampleStores is not supported ($n1, $n2)")
        # end

        i = names[n1]
        j = names[n2]

        corrmatrix[i, j] = corrmatrix[j, i] = corr[3]
    end

    return corrmatrix
end
