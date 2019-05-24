# Tutorial 2: Modify an Existing Model

This tutorial walks through the steps to modify an existing model.  There are several existing models publically available on Github, and for the purposes of this tutorial we will use MimiDICE2010, available on Github [here](https://github.com/anthofflab/MimiDICE2010.jl).

Working through the following tutorial will require:

- [Julia v1.1.0](https://julialang.org/downloads/) or higher
- [Mimi v0.8.0](https://github.com/mimiframework/Mimi.jl) 

If you have not yet prepared these, go back to the main tutorial page and follow the instructions for their download. 

Futhermore, this tutorial uses the [DICE](https://github.com/anthofflab/MimiDICE2010.jl) model as an example.  Downloading `DICE` uses similar steps to those described for `FUND` in Tutorial 1 Steps 1 and 2.

## Introduction

There are various ways to modify an existing model, and this tutorial aims to introduce the Mimi API relevant to this broad category of tasks.  It is important to note that regardless of the goals and complexities of your modifications, the API aims to allow for modification **without alteration of the original code for the model being modified**.  Instead, you will download and run the new model, and then use API calls to modify it. This means that in practice, you should not need to alter the source code of the model they are modifying. Thus, it is easy to keep up with any external updates or improvements made to that model.

Possible modifications range in complexity, from simply altering parameter values, to adjusting an existing component, to adding a brand new component. These take advantage of the public API listed [here](https://www.mimiframework.org/Mimi.jl/dev/reference/), as well as other functions listed in the Mimi Documentation.

## Parametric Modifications: The API

Several types of changes to models revolve around the parameters themselves, and may include updating the values of parameters and changing parameter connections without altering the elements of the components themselves or changing the general component structure of the model.  The most useful functions of the common API in these cases are likely **[`update_param!`](@ref)/[`update_params!`](@ref), [`disconnect_param!`](@ref), and [`connect_param!`](@ref)**.  For detail on these functions see the API reference [here](https://www.mimiframework.org/Mimi.jl/dev/reference/).

When the original model calls [`set_param!`](@ref), Mimi creates an external parameter by the name provided, and stores the provided scalar or array value. The functions [`update_param!`](@ref) and [`update_params!`](@ref) allow you to change the value associated with this external parameter.  Note that if the external parameter has a `:time` dimension, use the optional argument `update_timesteps=true` to indicate that the time keys (i.e., year labels) associated with the parameter should be updated in addition to updating the parameter values.

```julia
update_param!(mymodel, :parametername, newvalues) # update values only 

update_param!(mymodel, :parametername, newvalues, update_timesteps=true) # also update time keys
```

Also note that in the code above,`newvalues` must be the same size and type (or be able to convert to the type) of the old values stored in that parameter.

If you wish to alter connections within an existing model, [`disconnect_param!`](@ref) and [`connect_param!`](@ref) can be used in conjunction with each other to update the connections within the model, although this is more likely to be done as part of larger changes involving components themslves, as discussed in the next subsection.

## Parametric Modifications: DICE Example

### Step 1. Download DICE

The first step in this process is downloading the FUND model, which is now made easy with the Mimi registry.  Assuming you have already done the one-time run of the following to connect your julia installation with the central Mimi registry of Mimi models

```julia
pkg> registry add https://github.com/mimiframework/MimiRegistry.git
```

You simply need to add the DICE2010 model with 
```
add MimiDICE2010
```
You have now successfully downloaded DICE to your local machine.

### Step 2. Run DICE

The next step is to run DICE.  If you wish to first get more aquainted with the model itself, take a look at the provided online documentation.  Now run DICE using the provided API for the package:

```
using MimiDICE2010
m = construct_dice()
run(m)
```

Note that these steps should be relatively consistent across models, where a repository for `ModelX` should contain a primary file `ModelX.jl` which exports, at minimum, a function named something like `getModelX` or `construct_ModelX` which returns a version of the model, and can allow for model customization within the call.

In this case, the function `construct_dice` has the signature
``` 
construct_dice(params=nothing)
```
Thus there are no required arguments, although the user can input `params`, a dictionary definining the parameters of the model. 

### Step 3. Altering Parameters

In the case that you wish to alter an exogenous parameter, you may use the [`update_param!`](@ref) function.  For example, in DICE the parameter `fco22x` is the forcings of equilibrium CO2 doubling in watts per square meter, and exists in the components `climatedynamics` and `radiativeforcing`.  If you wanted to change this value from its default value of `3.200` to `3.000` in both components,you would use the following code:

```julia
update_param!(m, :fco22x, 3.000)
run(m)
```

A more complex example may a situation where you want to update several parameters, including some with a `:time` dimension, in conjunction with altering the time index of the model itself.  DICE uses a default time horizon of 2005 to 2595 with 10 year increment timesteps.  If you wish to change this, say, to 2000 to 2500 by 10 year increment timesteps and use parameters that match this time, you could use the following code:

First you upate the `time` dimension of the model as follows:
```julia
const ts = 10
const years = collect(2000:ts:2500)
nyears = length(years)
set_dimension!(m, :time, years)
```

Next, create a dictionary `params` with one entry (k, v) per external parameter by name k to value v. Each key k must be a symbol or convert to a symbol matching the name of an external parameter that already exists in the model definition.  Part of this dictionary may look like:

```julia
params = Dict{Any, Any}()
params[:a1]         = 0.00008162
params[:a2]         = 0.00204626
...
params[:S]          = repeat([0.23], nyears)
...
```

Now you simply update the parameters listen in `params` and re-run the model with

```
update_params!(m, params, update_timesteps=true)
run(m)
```

Note that here we use the `update_timesteps` flag and set it to `true`, because since we have changed the time index we want the time labels on the parameters to change, not simply their values.

## Component and Structural Modifications: The API

Most model modifications will include not only parametric updates, but also strutural changes and component modification, addition, replacement, and deletion along with the required re-wiring of parameters etc. The most useful functions of the common API, in these cases are likely **[`replace_comp!`](@ref), [`add_comp!`](@ref)** along with **`Mimi.delete!`** and the requisite functions for parameter setting and connecting.  For detail on the public API functions look at the API reference [here](https://www.mimiframework.org/Mimi.jl/dev/reference/). 

If you wish to modify the component structure we recommend you also look into the **built-in helper components `adder`, `ConnectorCompVector`, and `ConnectorCompMatrix`** in the `src/components` folder, as these can prove quite useful.  

* `adder.jl` -- Defines `Mimi.adder`, which simply adds two parameters, `input` and `add` and stores the result in `output`.

* `connector.jl` -- Defines a pair of components, `Mimi.ConnectorCompVector` and `Mimi.ConnectorCompMatrix`. These copy the value of parameter `input1`, if available, to the variable `output`, otherwise the value of parameter `input2` is used. It is an error if neither has a value.

## Component and Structural Modifications: DICE Example

 This example is in progress and will be built out soon.
