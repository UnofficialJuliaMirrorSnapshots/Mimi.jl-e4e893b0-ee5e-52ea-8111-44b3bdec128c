"""
    set_param!(ref::ComponentReference, name::Symbol, value)

Set a component parameter as `set_param!(reference, name, value)`.
"""
function set_param!(ref::ComponentReference, name::Symbol, value)
    set_param!(ref.model, ref.comp_name, name, value)
end

"""
    set_param!(ref.model, ref.comp_name, name, value)

Set a component parameter as `reference[symbol] = value`.
"""
function Base.setindex!(ref::ComponentReference, value, name::Symbol)
    set_param!(ref.model, ref.comp_name, name, value)
end

"""
    connect_param!(dst::ComponentReference, dst_name::Symbol, src::ComponentReference, src_name::Symbol)

Connect two components as `connect_param!(dst, dst_name, src, src_name)`.
"""
function connect_param!(dst::ComponentReference, dst_name::Symbol, src::ComponentReference, src_name::Symbol)
    connect_param!(dst.model, dst.comp_id, dst_name, src.comp_id, src_name)
end

"""
    connect_param!(dst::ComponentReference, src::ComponentReference, name::Symbol)
    
Connect two components with the same name as `connect_param!(dst, src, name)`.
"""
function connect_param!(dst::ComponentReference, src::ComponentReference, name::Symbol)
    connect_param!(dst.model, dst.comp_id, name, src.comp_id, name)
end


"""
    Base.getindex(comp_ref::ComponentReference, var_name::Symbol)

Get a variable reference as `comp_ref[var_name]`.
"""
function Base.getindex(comp_ref::ComponentReference, var_name::Symbol)
    VariableReference(comp_ref.model, comp_ref.comp_name, var_name)
end

"""
    Base.setindex!(comp_ref::ComponentReference, var_ref::VariableReference, var_name::Symbol)
    
Connect two components as `comp_ref[var_name] = var_ref`.
"""
function Base.setindex!(comp_ref::ComponentReference, var_ref::VariableReference, var_name::Symbol)
    comp_ref.model == var_ref.model || error("Can't connect variables defined in different models")

    connect_param!(comp_ref.model, comp_ref.comp_name, var_name, var_ref.comp_name, var_ref.var_name)
end
