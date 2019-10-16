#
# ComponentPath manipulation methods
#

Base.length(path::ComponentPath) = length(path.names)
Base.isempty(path::ComponentPath) = isempty(path.names)

head(path::ComponentPath) = (isempty(path) ? Symbol[] : path.names[1])
tail(path::ComponentPath) = ComponentPath(length(path) < 2 ? Symbol[] : path.names[2:end])

# The equivalent of ".." in the file system.
Base.parent(path::ComponentPath) = ComponentPath(path.names[1:end-1])

# Return a string like "/##ModelDef#367/top/Comp1"
function Base.string(path::ComponentPath)
    s = join(path.names, "/")
    return is_abspath(path) ? string("/", s) : s
end

Base.joinpath(p1::ComponentPath, p2::ComponentPath) = is_abspath(p2) ? p2 : ComponentPath(p1.names..., p2.names...)
Base.joinpath(p1::ComponentPath, other...) = joinpath(joinpath(p1, other[1]), other[2:end]...)

"""
    _fix_comp_path!(child::AbstractComponentDef, parent::AbstractCompositeComponentDef)

Set the ComponentPath of a child object to extend the path of its composite parent.
For composites, also update the component paths for all internal connections, and
for all DatumReferences in the namespace. For leaf components, also update the 
ComponentPath for ParameterDefs and VariableDefs.
"""
function _fix_comp_path!(child::AbstractComponentDef, parent::AbstractCompositeComponentDef)
    parent_path = parent.comp_path
    child.comp_path = child_path = ComponentPath(parent_path, child.name)
    # @info "Setting path of child $(child.name) with parent $parent_path to $child_path"
    
    # First, fix up child's namespace objs. We later recurse down the hierarchy.
    ns = child.namespace
    root = get_root(parent)

    for (name, ref) in ns
        if ref isa AbstractDatumReference
            T = typeof(ref)
            ns[name] = new_ref = T(ref.name, root, child_path)
            #@info "old ref: $ref, new: $new_ref"
        end
    end

    # recursively reset all comp_paths to their abspath equivalent
    if is_composite(child)

        # Fix internal param conns
        conns = child.internal_param_conns
        for (i, conn) in enumerate(conns)
            src_path = ComponentPath(child_path, conn.src_comp_path)
            dst_path = ComponentPath(child_path, conn.dst_comp_path)

            # @info "Resetting IPC src in $child_path from $(conn.src_comp_path) to $src_path"
            # @info "Resetting IPC dst in $child_path from $(conn.dst_comp_path) to $dst_path"

            # InternalParameterConnections are immutable, but the vector holding them is not
            conns[i] = InternalParameterConnection(src_path, conn.src_var_name, dst_path, conn.dst_par_name,
                                                   conn.ignoreunits, conn.backup; offset=conn.offset)
        end

        # Fix external param conns
        conns = child.external_param_conns
        for (i, conn) in enumerate(conns)
            path = ComponentPath(parent_path, conn.comp_path)
            # @info "Resetting EPC $child_path from $(conn.comp_path) to $path"

            conns[i] = ExternalParameterConnection(path, conn.param_name, conn.external_param)
        end

        for cd in compdefs(child)
            _fix_comp_path!(cd, child)
        end
    else
        for datum in [variables(child)..., parameters(child)...]
            datum.comp_path = child_path
        end
    end
end

"""
    fix_comp_paths!(md::AbstractModelDef)

Recursively set the ComponentPaths in a tree below a ModelDef to the absolute path equivalent.
This includes updating the component paths for all internal/external connections, and all
DatumReferences in the namespace. For leaf components, we also update the ComponentPath for 
ParameterDefs and VariableDefs.
"""
function fix_comp_paths!(md::AbstractModelDef)
    for child in compdefs(md)
        _fix_comp_path!(child, md)
    end
end

"""
    comp_path(node::AbstractCompositeComponentDef, path::AbstractString)

Convert a string describing a path from a node to a ComponentPath. The validity
of the path is not checked. If `path` starts with "/", the first element in the
returned component path is set to the root of the hierarchy containing `node`.
"""
function comp_path(node::AbstractCompositeComponentDef, path::AbstractString)
    # empty path means just select the node's path
    isempty(path) && return node.comp_path

    elts = split(path, "/")

    if elts[1] == ""    # path started with "/"
        root = get_root(node)
        elts[1] = string(nameof(root))
    end
    return ComponentPath([Symbol(elt) for elt in elts])
end

# For leaf components, we can only "find" the component itself
# when the path is empty.
function find_comp(obj::ComponentDef, path::ComponentPath)
    return isempty(path) ? obj : nothing
end

function find_comp(obj::AbstractComponentDef, name::Symbol)
    # N.B. test here since compdef doesn't check existence
    return has_comp(obj, name) ? compdef(obj, name) : nothing
end


function find_comp(obj::AbstractCompositeComponentDef, path::ComponentPath)
    # @info "find_comp($(obj.name), $path)"
    # @info "obj.parent = $(printable(obj.parent))"

    if isempty(path)
        return obj
    end

    # Convert "absolute" path from a root node to relative
    if is_abspath(path)
        path = rel_path(obj.comp_path, path)
        # @info "abspath converted to relpath is $path"

    elseif (child = find_comp(obj, head(path))) !== nothing
        # @info "path is unchanged: $path"


    elseif nameof(obj) == head(path)
        # @info "nameof(obj) == head(path); path: $(printable(path))"
        path = tail(path)
    else
        error("Cannot find path $(printable(path)) from component $(printable(obj.comp_id))")
    end

    names = path.names
    if has_comp(obj, names[1])
        return find_comp(compdef(obj, names[1]), ComponentPath(names[2:end]))
    end

    return nothing
end

function find_comp(obj::AbstractCompositeComponentDef, pathstr::AbstractString)
    path = comp_path(obj, pathstr)
    find_comp(obj, path)
end

find_comp(dr::AbstractDatumReference) = find_comp(dr.root, dr.comp_path)

find_comp(cr::ComponentReference) = find_comp(cr.parent, cr.comp_path)

"""
Return the relative path of `descendant` if is within the path of composite `ancestor` or
or nothing otherwise.
"""
function rel_path(ancestor_path::ComponentPath, descendant_path::ComponentPath)
    a_names = ancestor_path.names
    d_names = descendant_path.names

    if ((a_len = length(a_names)) >= (d_len = length(d_names)) || d_names[1:a_len] != a_names)
        # @info "rel_path($a_names, $d_names) returning nothing"
        return nothing
    end

    return ComponentPath(d_names[a_len+1:end])
end

rel_path(obj::AbstractComponentDef, descendant_path::ComponentPath) = rel_path(obj.comp_path, descendant_path)

"""
Return whether component `descendant` is within the composite structure of `ancestor` or
any of its descendants. If the comp_paths check out, the node is located within the
structure to ensure that the component is really where it says it is. (Trust but verify!)
"""
function is_descendant(ancestor::AbstractCompositeComponentDef, descendant::AbstractComponentDef)
    a_path = ancestor.comp_path
    d_path = descendant.comp_path
    if d_path === nothing || (relpath = rel_path(a_path, d_path)) === nothing
        return false
    end

    # @info "is_descendant calling find_comp($a_path, $relpath)"
    return find_comp(ancestor, relpath)
end

"""
    is_abspath(path::ComponentPath)

Return true if the path starts from a ModelDef, whose name is generated with
gensym("ModelDef") names look like Symbol("##ModelDef#123")
"""
function is_abspath(path::ComponentPath)
    return ! isempty(path) && match(r"^##ModelDef#\d+$", string(path.names[1])) !== nothing
end
