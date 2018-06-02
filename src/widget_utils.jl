using Vue

import WebIO: camel2kebab

export observe

const _pkg_root = dirname(dirname(@__FILE__))
const _pkg_deps = joinpath(_pkg_root,"deps")
const _pkg_assets = joinpath(_pkg_root,"assets")

# store mapping from widgets to respective scope
widgscopes = Dict{Any, Scope}()
scope(widget::Scope)::Union{Scope, Void} = widget
scope(widget)::Union{Scope, Void} =  get(widgscopes, widget, nothing)

# store mapping from widgets to observables
widgobs = Dict{Any, Observable}()
# users access a widgest's Observable via this function
observe(widget::Scope) = widgobs[widget]
observe(widget::Void) = nothing
observe(widget) = get(widgobs, widget, observe(scope(widget)))

observe(widget::Scope, s) = widget[s]
observe(widget::Void, s) = nothing
observe(widget, s) = observe(scope(widget), s)

"""
sets up a primary scope for widgets
that are not a scope
"""
function primary_scope!(w, sc)
    widgscopes[w] = sc
end

"""
sets up a primary observable for every
widget for use in @manipulate
"""
function primary_obs!(w, ob)
    widgobs[w] = ob
end
primary_obs!(w, ob::String) = primary_obs!(w, w[ob])

# Get median elements of ranges, used for initialising sliders.
# Differs from median(r) in that it always returns an element of the range
medianidx(r) = (1+length(r)) ÷ 2
medianelement(r::Union{Range, Array}) = r[medianidx(r)]
medianval(r::Associative) = medianelement(collect(values(r)))
medianelement(r::Associative) = medianval(r)

inverse_dict(d::Associative) = Dict(zip(values(d), keys(d)))

const Propkey = Union{Symbol, String}

"""
`props2str(vbindprops::Dict{Propkey, String}, stringprops::Dict{String, String}`
input is
`vbindprops`: Dict of v-bind propnames=>values, e.g. Dict("max"=>"max", "min"=>"min"),
`stringprops`: Dict of vanilla string props, e.g. Dict("v-model"=>"value")
output is `"v-bind:max=max, v-bind:min=min, v-model=value"`
"""
function props2str(vbindprops::Dict{Propkey, String}, stringprops::Dict{String, String})
    vbindpropstr = ["v-bind:$key = $val" for (key, val) in vbindprops]
    vpropstr = ["$key = $val" for (key, val) in stringprops]
    join(vcat(vbindpropstr, vpropstr), ", ")
end

"""
`kwargs2vueprops(kwargs)` => `vbindprops, data`

Takes a vector of kwarg (propname, value) Tuples, returns neat properties
and data that can be passed to a vue instance.

Does camel2kebab conversion that allows passing normally kebab-cased html props
as camelCased keyword arguments.

To enable non-string values in html properties, we can use vue's "v-bind:".
To do so, a `(propname, value)` pair, passed as a kwarg, will be encoded as
`"v-bind:propkey=propname"`, (where `propkey = \$(camel2kebab(propname))`, i.e.
just the propname converted to kebab case). The value will be stored in a
corresponding entry in the returned `data` Dict, `propname=>value`

So we have the following for a ((camelCased) propname, value) pair:
`propkey == camel2kebab(propname)`
`propname == vbindprops[propkey]`
`data[propname] == value`
Note that the data dict requires the camelCased propname in the keys
"""
function kwargs2vueprops(kwargs; extra_vbinds=Dict())
    extradata = Dict(values(extra_vbinds))
    extravbind_dic = Dict{String, String}(
        zip(map(camel2kebab, keys(extra_vbinds)), keys(extradata)))
    data = Dict{Propkey, Any}(merge(Dict(kwargs), extradata))
    camelkeys = map(string, keys(data))
    propapropkeys = camel2kebab.(camelkeys) # kebabs are propa bo
    vbindprops = Dict{Propkey, String}(zip(propapropkeys, camelkeys))
    merge(vbindprops, extravbind_dic), data
end

function slap_design!(w::Scope, args)
    for arg in args
        import!(w, arg)
    end
    w
end

slap_design!(w::Scope, args::AbstractString...) = slap_design!(w::Scope, args)

slap_design!(w::Scope, args::WidgetTheme = gettheme()) =
    slap_design!(w::Scope, libraries(args))

slap_design!(n::Node, args...) = slap_design!(Scope()(n), args...)

function wrap(T::WidgetTheme, ui, f = dom"div.field")
    wrapped_ui = f(ui)
    primary_scope!(wrapped_ui, scope(ui))
    wrapped_ui
end

isijulia() = isdefined(Main, :IJulia) && Main.IJulia.inited