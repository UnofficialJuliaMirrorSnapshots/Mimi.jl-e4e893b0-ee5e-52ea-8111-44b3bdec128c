module TestMain

using Test
using Mimi

import Mimi: 
    reset_variables, @defmodel, 
    variable, variable_names, external_param, build, 
    compdefs, dimension, compinstance

@defcomp foo1 begin
    index1 = Index()

    par1 = Parameter()
    par2::Bool = Parameter(index=[time,index1], description="description par 1")
    par3 = Parameter(index=[time])

    var1 = Variable()
    var2 = Variable(index=[time])
    var3 = Variable(index=[time,index1])

    idx3 = Index()
    idx4 = Index()
    var4::Bool = Variable(index=[idx3])
    var5 = Variable(index=[index1, idx4])
end


@defmodel x1 begin
    index[index1] = [:r1, :r2, :r3]
    index[time] = 2010:10:2030
    index[idx3] = 1:3
    index[idx4] = 1:4
    component(foo1)

    foo1.par1 = 5.0
end

# x1 = foo1(Float64, Dict{Symbol, Int}(:time=>10, :index1=>3))
# x1 = foo1(Float64, Val{1}, Val{1}, Val{10}, Val{1}, Val{1}, Val{1}, Val{1}, Dict{Symbol, Int}(:time=>10, :index1=>3))

@test length(dimension(x1.md, :index1)) == 3

# @test_throws MethodError x1.Parameters.par1 = Array{Float64}(undef, 1, 2)

par1 = external_param(x1, :par1)
@test par1.value == 5.0

set_param!(x1, :foo1, :par1, 6.0)
par1 = external_param(x1, :par1)
@test par1.value == 6.0

set_param!(x1, :foo1, :par2, [true true false; true false false; true true true])

set_param!(x1, :foo1, :par3, [1.0, 2.0, 3.0])

build(x1)

ci = compinstance(x1, :foo1)
reset_variables(ci)

# Check all variables are defaulted
@test isnan(get_var_value(ci, :var1))

m = Model()
set_dimension!(m, :time, 20)
set_dimension!(m, :index1, 5)
add_comp!(m, foo1)

@test :var1 in variable_names(x1, :foo1)

end # module
