module TestDimensions

using Mimi
using Test

import Mimi:
    compdef, AbstractDimension, RangeDimension, Dimension, key_type, first_period, last_period,
    ComponentReference

dim_varargs = Dimension(:foo, :bar, :baz)   # varargs
dim_vec = Dimension([:foo, :bar, :baz]) # Vector		
dim_range = Dimension(2010:2100)     # AbstractRange	
rangedim = RangeDimension(2010:2100) # RangeDimension type	
dim_vals = Dimension(4) # Same as 1:4

# RJP: unclear what was intended here, but you cannot instantiate an abstract type...
# dim_vals_abstract = AbstractDimension(dim_vals) # Abstract

@test key_type(dim_varargs) == Symbol
@test key_type(dim_vec) == Symbol
@test key_type(dim_range) == Int
@test key_type(dim_vals) == Int

@test length(dim_varargs) == 3
@test length(dim_vec) == 3
@test length(dim_vals) == 4
@test length(dim_range) == 91
@test length(rangedim) == 91

# Test iteration
@test [x.first for x in dim_varargs] == collect(keys(dim_varargs))
@test [x.first for x in dim_range]   == collect(keys(dim_range))

@test lastindex(dim_varargs) == :baz
@test lastindex(dim_vec) == :baz
@test lastindex(dim_range) == 2100
@test lastindex(dim_vals) == 4


@test Base.keys(rangedim) == [2010:2100...]
@test Base.values(rangedim) == [1:91...]

for i = 1:length(dim_range)
    @test getindex(dim_range, 2010 + i - 1) == i
end
@test dim_range[:] == [1:91...]
@test dim_varargs[:bar] == 2
@test dim_varargs[:] == [1,2,3]

# @test dim_vals_abstract[1:4...]== [1:4...]

# @test rangedim[2011] == 2 # TODO: this errors..

@test get(dim_varargs, :bar, 999) == 2
@test get(dim_varargs, :new, 4) == 4 #adds a key/value pair
@test get(rangedim, 2010, 1) == 1 
# @test get(rangedim, 2101, 92) == 92 # TODO:  this errors ...

#test iteratable
dim_vals2 = Dimension(2:2:8)
intkeys = [2,4,6,8]
# Work around new global scoping rules
# Without the `let`, `index` is unknown in the for loop
let index = 1
    for pair in dim_vals2
        @test dim_vals2[intkeys[index]] == index
        index += 1
    end
end

rangedim2 = RangeDimension(2:2:8)
# Work around new global scoping rules
# Without the `let`, `index` is unknown in the for loop
let index = 1
    for pair in rangedim2   # uses iterate()
        @test get(rangedim2, Base.keys(rangedim2)[index]) == index
        index += 1
    end
end

@test getindex(dim_varargs, :bar) == 2
@test getindex(dim_varargs, :) == [1,2,3]


# Test resetting the time dimension

@defcomp foo2 begin 
    x = Parameter(index=[time]) 
    y = Variable(index=[4])
end 

m = Model()
set_dimension!(m, :time, 2000:2100)

# First and last have been disabled...
#@test_throws ErrorException add_comp!(m, foo2; first = 2005, last = 2105)   # Can't add a component longer than a model

@test_logs(
    (:warn, "add_comp!: Keyword arguments 'first' and 'last' are currently disabled."),
    foo2_ref = add_comp!(m, foo2; first = 2005, last = 2095)
)

foo2_ref = ComponentReference(m, :foo2)
my_foo2 = compdef(foo2_ref)

# First and last have been disabled... 
# Can't set time more narrowly than components are defined as
# @test_throws ErrorException set_dimension!(m, :time, 1990:2200)
# @test first_period(my_foo2) == 2005
# @test last_period(my_foo2)  == 2095

# Test parameter connections
# @test_throws ErrorException set_param!(m, :foo2, :x, 1990:2200) # too long
# set_param!(m, :foo2, :x, 2005:2095) # Shouldn't throw an error

set_dimension!(m, :time, 2010:2050)

@test first_period(m.md) == 2010
@test last_period(m.md)  == 2050

end #module
