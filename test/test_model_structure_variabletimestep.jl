module TestModelStructure_VariableTimestep

#tests the framework of components and connections

using Test
using Mimi

import Mimi:
    connect_param!, unconnected_params, set_dimension!, has_comp,
    get_connections, internal_param_conns, dim_count, 
    dim_names, compdef, getproperty, setproperty!, dimension, compdefs

@defcomp A begin
    varA::Int = Variable(index=[time])
    parA::Int = Parameter()

    function run_timestep(p, v, d, t)
        v.varA[t] = p.parA
    end
end

@defcomp B begin
    varB::Int = Variable()

    function run_timestep(p, v, d, t)
        if t.t < 10
            v.varB = 1
        else
            v.varB = 10
        end
    end
end

@defcomp C begin
    varC::Int = Variable()
    parC::Int = Parameter()

    function run_timestep(p, v, d, t)
        v.varC = p.parC
    end
end

years = [2015:5:2100; 2110:10:2200]
first_A = 2050
last_A = 2150

m = Model()
set_dimension!(m, :time, years)

# first and last are now disabled
# @test_throws ErrorException add_comp!(m, A, last = 2210)
# @test_throws ErrorException add_comp!(m, A, first = 2010)

@test_logs(
    (:warn, "add_comp!: Keyword arguments 'first' and 'last' are currently disabled."),
    add_comp!(m, A, last = 2210)
)

# remove the comp we just added so later tests succeed
delete!(m, :A)
@test has_comp(m, :A) == false

@test_throws ArgumentError add_comp!(m, A, after=:B)
# @test_throws ErrorException add_comp!(m, A, after=:B)

@test_logs(
    (:warn, "add_comp!: Keyword arguments 'first' and 'last' are currently disabled."),
    add_comp!(m, A, first = first_A, last = last_A) #test specific last and first
)

add_comp!(m, B, before=:A)

add_comp!(m, C, after=:B) # test a later first than model
# Component order is B -> C -> A.

connect_param!(m, :A, :parA, :C, :varC)

unconn = unconnected_params(m)
@test length(unconn) == 1
c = compdef(m, :C)
@test unconn[1] == (c.comp_path, :parC)

connect_param!(m, :C => :parC, :B => :varB)

@test_throws ErrorException add_comp!(m, C, after=:A, before=:B)

@test length(m.md) == 3

@test length(internal_param_conns(m)) == 2
c = compdef(m, :C)
@test get_connections(m, :A, :incoming)[1].src_comp_path == c.comp_path

@test length(get_connections(m, :B, :incoming)) == 0
c = compdef(m, :C)
@test get_connections(m, :B, :outgoing)[1].dst_comp_path == c.comp_path

@test length(get_connections(m, :A, :all)) == 1

@test length(unconnected_params(m)) == 0

#############################################
#  Tests for connecting scalar parameters   #
#############################################

run(m)

# @test all([m[:A, :varA][t] == 1 for t in 1:2])
# @test all([m[:A, :varA][t] == 10 for t in 3:16])

dim = Mimi.Dimension(years)
varA = m[:A, :varA][dim[first_A]:dim[last_A]]
@test all([varA[i] == 1 for i in 1:2])
@test all([varA[i] == 10 for i in 3:16])

##########################
#   tests for indexing   #
##########################

@test dim_count(m.md, :time) == 28

@test m[:A, :parA] == 10
@test_throws ErrorException m[:A, :xx]

time = dimension(m, :time)
a = collect(keys(time))
@test all([a[i] == years[i] for i in 1:28])

@test dim_names(m, :A, :varA)[1] == :time
@test length(dim_names(m, :A, :parA)) == 0

################################
#  tests for delete! function  #
################################

@test_throws ErrorException delete!(m, :D)
@test length(internal_param_conns(m.md)) == 2
delete!(m, :A)
@test length(internal_param_conns(m.md)) == 1
@test !(:A in compdefs(m))
@test length(compdefs(m)) == 2

#######################################
#   Test check for unset parameters   #
#######################################

@defcomp D begin
  varD = Variable(index=[time])
  parD = Parameter()
end

add_comp!(m, D)
@test_throws ErrorException Mimi.build(m)

end # module
