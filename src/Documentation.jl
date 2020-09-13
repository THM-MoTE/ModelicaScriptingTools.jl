"""
    getDocAnnotation(omc:: OMCSession, name:: String)

Returns documentation string from model annotation and strips `<html>` tag if
necessary.
"""
function getDocAnnotation(omc:: OMCSession, model:: String)
    htmldoc = sendExpression(omc, "getDocumentationAnnotation($model)")[1]
    ishtml = match(r"\s*<\s*html[^>]*>(.*)\s*</\s*html\s*>\s*"s, htmldoc)
    if !isnothing(ishtml)
        htmldoc = ishtml.captures[1]
    end
    return htmldoc
end

"""
    getcode(omc:: OMCSession, model:: String)

Returns the code of the given model or class as a string.
"""
function getcode(omc:: OMCSession, model:: String)
    cwd = sendExpression(omc, "cd()")
    tmpfile = joinpath(cwd, "export_$model.mo")
    sendExpression(omc, "saveModel(\"$(moescape(tmpfile))\", $model)")
    return read(tmpfile, String)
end

"""
    getequations(omc:: OMCSession, model::String)

Returns all equations of the given model as a list of strings with
presentation MathML syntax.
"""
function getequations(omc:: OMCSession, model::String)
    res = sendExpression(omc, "dumpXMLDAE($model, addMathMLCode=true)")
    err = sendExpression(omc, "getErrorString()")
    if !isempty(err)
        throw(MoSTError("Could not save model as independent XML file", err))
    end
    res = py"extract_equations"(res[2], xslt_dir=joinpath(@__DIR__, "..", "res"))
    return res
end

"""
    getfunctions(omc:: OMCSession, model:: String)

Returns all functions of the given model as a twodimensional array where each
row contains the function name, the function header, and the modelica definition
of the function in this order.
"""
function getfunctions(omc:: OMCSession, model:: String)
    res = sendExpression(omc, "dumpXMLDAE($model, addMathMLCode=true)")
    err = sendExpression(omc, "getErrorString()")
    if !isempty(err)
        throw(MoSTError("Could not save model as independent XML file", err))
    end
    funcs = py"extract_functions"(res[2])
    for i in 1:size(funcs)[1]
        # removes function name from end of header (i.e. from return type)
        if endswith(funcs[i,2], funcs[i,1])
            funcs[i,2] = funcs[i,2][1:end-length(funcs[i,1])-1]
        end
        funcs[i, 3] = replace(funcs[i, 3], "\"Inline if necessary\"" => "")
    end
    if isempty(funcs)
        return Array{String}(undef, 0, 2)
    else
        return funcs
    end
end

function algorithm(code:: AbstractString)
    funcname = match(
        r"^\s*function ([\w.$]+)",
        split(code, r"\r?\n")[1]
    ).captures[1]
    return match(
        Regex("algorithm\\n((?:.|\\n)+)end \\Q$funcname\\E;"),
        code
    ).captures[1]
end

function uniquefunctions(funcs:: Array)
    alg2func = Dict{String, Array{String, 2}}()
    for i in 1:size(funcs)[1]
        a = algorithm(funcs[i, 3])
        alg2func[a] = get(alg2func, a, Array{String}(undef, 0, 3))
        alg2func[a] = [alg2func[a]; permutedims(funcs[i, :])]
    end
    aliases = Dict()
    res = Array{String}(undef, 0, 3)
    for a in keys(alg2func)
        group = alg2func[a]
        prototype = group[1, :]
        res = [res; permutedims(prototype)]
        for i in 1:size(group)[1]
            aliases[group[i, 1]] = prototype[1,1]
        end
    end
    return (aliases, res)
end


"""
    uniquehierarchy(names:: Array{<: AbstractString})

Returns a dictionary that maps the given names to the minimal hierarchical
postfix that is required to make the name unique.
A hierarchical postfix is a postfix that begins after a dot.
For example, `ab.cd.ef` has the hierarchical postfixes `ef`, `cd.ef` and
`ab.cd.ef`.
"""
function uniquehierarchy(names:: Array{<: AbstractString})
    function postfix(n, i)
        join(split(n, ".")[end-i+1:end], ".")
    end
    restoredollar = Dict(replace(x, '$' => '.') => x for x in names)
    res = Dict()
    remaining = Set(keys(restoredollar))
    i = 1
    while !isempty(remaining)
        namesdone = filter(
            x -> count(a -> endswith(a, postfix(x, i)), remaining) == 1,
            remaining
        )
        for n in namesdone
            res[restoredollar[n]] = postfix(n, i)
            delete!(remaining, n)
        end
        i += 1
    end
    return res
end


"""
    getvariables(omc:: OMCSession, model::String)

Returns an array of dictionaries that contain the following keys describing
the variables and parameters of the given model.

* "name": the name of the variable
* "variability": is the variable a parameter, a constant, or a variable?
* "type": the data type of the variable (usually "Real")
* "label": the string label attached to the variable
* "quantity": the kind of physical quantity modeled by the variable
* "unit": the unit of the variable in Modelica unit syntax
* "initial": the initial value of the variable, if existent
* "bindExpression": the expression used to fix the variable value, if existent
* "aliasof": the name of the other variable of which this variable is an alias

An empty string is used as value for keys which are not applicable for the given variable.
"""
function getvariables(omc:: OMCSession, model::String)
    res = sendExpression(omc, "dumpXMLDAE($model, addMathMLCode=true)")
    err = sendExpression(omc, "getErrorString()")
    if !isempty(err)
        throw(MoSTError("Could not save model as independent XML file", err))
    end
    res = py"extract_variables"(res[2], xslt_dir=joinpath(@__DIR__, "..", "res"))
    return res
end

"""
    mdescape(s:: String)

Escapes characters that have special meaning in Markdown with a backslash.
"""
function mdescape(s:: String)
    escape_chars = "\\`*_#+-.!{}[]()\$"
    return join([(x in escape_chars ? "\\$x" : x) for x in s])
end

"""
    variabletable(vars:: Array{Dict{Any, Any},1})

Creates a Markdown table from an array of variable descriptions as returned
by [`getvariables(omc:: OMCSession, model::String)`](@ref).
"""
function variabletable(vars:: Array{Dict{Any, Any},1})
    header = """
    |name|unit|value|label|
    |----|----|-----|-----|
    """
    lines = []
    for v in vars
        if length(v["aliasof"]) > 0
            continue # exclude aliases from table
        end
        value = if length(v["initial"]) == 0
            v["bindExpression"]
        else
            v["initial"]
        end
        vals = [v["name"], v["unit"], value, v["label"]]
        vals = [mdescape(x) for x in vals]
        push!(lines, "|$(join(vals, "|"))|")
    end
    table = "$(header)$(join(lines, "\n"))"
    return Markdown.parse(table)
end

function replacefuncnames(equation:: AbstractString, replacements:: Dict)
    res = equation
    for n in keys(replacements)
        res = replace(
            res,
            Regex("<mi>\\s*\\Q$n\\E\\s*</mi>")
            => SubstitutionString("<mi>$(replacements[n])</mi>")
        )
    end
    return res
end

const ellipse = "_"

function equationlist(equations:: Array{<: AbstractString}, vars:: Array{Dict{Any, Any}, 1}, funcs:: Array)
    function hierarchify(equations:: Array)
        res = Dict()
        for (pref, eq) in equations
            levels = split(pref, ".")
            target = res
            for l in levels
                if l == "" continue end
                if !haskey(target, l) target[l] = Dict() end
                target = target[l]
            end
            if !haskey(target, "") target[""] = [] end
            push!(target[""], eq)
        end
        return res
    end
    function htmlify(hierarchy:: Dict)
        entries = []
        for k in sort(collect(keys(hierarchy)))
            v = hierarchy[k]
            if k == ""
                for e in v
                    push!(entries, "<li>$e")
                end
            else
                push!(entries, "<li>Within group $k (prefix $ellipse indicates shortened variable name)\n$(htmlify(v))")
            end
        end
        """
        <ol>
        $(join(entries, "\n"))
        </ol>
        """
    end
    funcdict = uniquehierarchy(funcs[1:end, 1])
    equations = [replacefuncnames(e, funcdict) for e in equations]
    equations = collect(map(explicify, equations))
    aliases = aliasdict(vars)
    prefixes = [commonhierarchy(e, aliases) for e in equations]
    pruneprefixes!(prefixes)
    equations = [(p, deprefix(e, p)) for (e, p) in zip(equations, prefixes)]
    return htmlify(hierarchify(equations))
end

function functionlist(funcs:: Array)
    replacements = uniquehierarchy(funcs[1:end, 1])
    res = ["Functions:"]
    for i in 1:size(funcs)[1]
        fun = funcs[i, 1]
        rep = replacements[fun]
        code = funcs[i, 3]
        cleaned = strip(replace(code, fun => rep))
        push!(res, "```modelica\n$cleaned\n```")
    end
    return Markdown.parse(join(res, "\n\n"))
end

# extend Documenter with new code block type @modelica
abstract type ModelicaBlocks <: Documenter.Expanders.ExpanderPipeline end
Documenter.Selectors.order(::Type{ModelicaBlocks}) = 5.0
Documenter.Selectors.matcher(::Type{ModelicaBlocks}, node, page, doc) = Documenter.Expanders.iscode(node, "@modelica")
function Documenter.Selectors.runner(::Type{ModelicaBlocks}, x, page, doc)
    cd(page.workdir) do
        result = ""
        modelnames = []
        result = []
        nullary(x) = Regex("%\\s*$x\\s*")
        unary(x) = Regex("%\\s*$x\\s*=\\s*(.*)")
        magics = Dict(
            "modeldir" => unary("modeldir"),
            "outdir" => unary("outdir"),
            "nocode" => nullary("nocode"),
            "noequations" => nullary("noequations"),
            "noinfo" => nullary("noinfo")
        )
        magicvalues = Dict()
        # get list of models and magic values
        for (line) in split(x.code, '\n')
            if startswith(line, '%')
                try
                    matches = [(k, match(v, line)) for (k, v) in magics]
                    matches = filter(p -> !isnothing(p[2]), matches)
                    if isempty(matches)
                        throw(MoSTError("magic line type in '$line' not recognized", ""))
                    end
                    name, rmatch = first(matches)
                    magicvalues[name] = if isempty(rmatch.captures)
                        true
                    else
                        string(rmatch.captures[1])
                    end
                catch err
                    push!(doc.internal.errors, :eval_block)
                    @warn("""
                        invalid magic line starting with '%' in `@modelica` block in $(Documenter.Utilities.locrepr(page.source))
                        ```$(x.language)
                        $(x.code)
                        ```
                        """, exception = err)
                end
            else
                push!(modelnames, String(line))
            end
        end
        # communicate with OMC to obtain documentation and equations
        try
            modeldir = get(magicvalues, "modeldir", "../..")
            outdir = get(magicvalues, "outdir", joinpath(modeldir, "../out"))
            withOMC(outdir, modeldir) do omc
                for (model) in modelnames
                    # TODO automatically decide what to do based on class type
                    # load model without all extra checks
                    loadModel(omc, model; ismodel=false)
                    # get documentation as HTML string
                    if !get(magicvalues, "noinfo", false)
                        htmldoc = getDocAnnotation(omc, model)
                        push!(result, Documenter.Documents.RawHTML(htmldoc))
                    end
                    # get model code
                    if !get(magicvalues, "nocode", false)
                        rawcode = getcode(omc, model)
                        push!(result, Documenter.Utilities.mdparse("```modelica\n$rawcode\n```\n"))
                    end
                    # TODO alternative way to get equations through getNthEquationItem()
                    # get model equations
                    if !get(magicvalues, "noequations", false)
                        equations = getequations(omc, model)
                        vars = getvariables(omc, model)
                        funcs = getfunctions(omc, model)
                        htmleqs = equationlist(equations, vars, funcs)
                        push!(result, Documenter.Documents.RawHTML(htmleqs))
                        funclist = functionlist(funcs)
                        push!(result, funclist)
                        vartab = variabletable(vars)
                        push!(result, vartab)
                    end
                end
            end
        catch err
            push!(doc.internal.errors, :eval_block)
            @warn("""
                failed to evaluate `@modelica` block in $(Documenter.Utilities.locrepr(page.source))
                ```$(x.language)
                $(x.code)
                ```
                """, exception = err)
        end
        page.mapping[x] = Documenter.Documents.MultiOutput(result)
    end
end

function commonprefix(str:: AbstractString...)
    # based on https://rosettacode.org/wiki/Longest_common_prefix#Julia
    if isempty(str) return "" end
    i = 1
    ref = str[1]
    while all(i ≤ length(s) && s[i] == ref[i] for s in str)
        i += 1
    end
    return ref[1:i-1]
end

function commonprefix(aliasgroups:: Set{<:AbstractString}...)
    if isempty(aliasgroups) return "" end
    res = []
    # if all aliasgroups have >= 2 elements, iterate over smallest group
    smallest = reduce((x, y) -> if length(x) < length(y) x else y end, aliasgroups)
    for ref in smallest
        push!(res, commonprefix(collect(aliasgroups), ref))
    end
    largestprefix = reduce((x, y) -> if length(x) > length(y) x else y end, res)
    return largestprefix
end

function commonprefix(aliasgroups:: Array{<:Set{<:AbstractString},1}, ref:: AbstractString)
    if isempty(aliasgroups) return "" end
    aliasgroups = deepcopy(aliasgroups)
    i = 1
    while all(length(g) > 0 for g in aliasgroups)
        for g in aliasgroups
            filter!(x -> length(x) ≥ i && x[i] == ref[i], g)
        end
        i += 1
    end
    return ref[1:i-2]
end

function commonhierarchy(str:: Union{AbstractString, Set{<:AbstractString}}...)
    pref = commonprefix(str...)
    i = findlast('.', pref)
    if isnothing(i) return "" end
    return pref[1:i-1]
end

function findvarnames(str:: AbstractString)
    idnames = findidentifiers(str)
    fnames = findfuncnames(str)
    varnames = setdiff(idnames, fnames)
    return varnames
end

function findfuncnames(str:: AbstractString)
    pattern = r"<mi>\s*([\w.$]+)\s*<\/mi>\s*</mrow>\s*<mo>&#8289;</mo>"
    funcnames = [x.captures[1] for x in eachmatch(pattern, str)]
    return funcnames
end

function findidentifiers(str:: AbstractString)
    mi = r"<mi>\s*([\w.$]+)\s*<\/mi>"
    identifiers = [x.captures[1] for x in eachmatch(mi, str)]
    return identifiers
end

const commonconsts = Set(["e", "π", "c", "h", "G", "F", "R"])

function commonhierarchy(str:: AbstractString, aliases:: Dict{<:AbstractString, <:Set{<:AbstractString}})
    varnames = findvarnames(str)
    varnames = setdiff(varnames, commonconsts)
    aliasgroups = [get(aliases, n, Set{String}()) ∪ Set([n]) for n in varnames]
    pref = commonhierarchy(aliasgroups...)
    return pref
end

function deprefix(str:: AbstractString, pref:: AbstractString)
    de = replace(
        str,
        Regex("<mi>\\s*$pref\\.([\\w.]+)\\s*</mi>")
        => SubstitutionString("<mi>$ellipse\\1</mi>")
    )
    return de
end

function explicify(mml:: AbstractString)
    # use visible "dot operator" instead of "invisible times"
    # justification: our variables have multi-character names
    replace(mml, "&#8290;" => "&sdot;")
end

function pruneprefixes!(prefs:: Array{<: AbstractString})
    counts = Dict(k => 0 for k in prefs)
    for p in prefs
        counts[p] += 1
    end
    while !all(([counts[p] for p in prefs] .> 1) .| (prefs .== ""))
        # index of longest single entry
        pi = argmax(map(x -> if counts[x] == 1 length(x) else 0 end, prefs))
        delete!(counts, prefs[pi])
        # remove last hierarchical level from prefix
        prefs[pi] = join(split(prefs[pi], ".")[1:end-1], ".")
        counts[prefs[pi]] = get(counts, prefs[pi], 0) + 1
    end
end

function aliasdict(vars:: Array{Dict{Any, Any},1})
    aliases = Dict{String, Set{String}}()
    for v in vars
        alias = v["name"]
        original = v["aliasof"]
        if length(original) == 0 continue end
        aliases[original] = get(aliases, original, Set{String}())
        push!(aliases[original], alias)
    end
    return aliases
end

function __init__doc()
    # import only used to install lxml automatically
    pyimport_conda("lxml.etree", "lxml")
    py"""
    import lxml.etree as et
    import lxml.objectify as lo
    import io
    import os

    def load_ctop(dirname):
        xslt = et.parse(os.path.join(dirname, "ctop.xsl"))
        tf = et.XSLT(xslt)
        return tf

    def cleanup_mathml(dom):
        # reference: https://stackoverflow.com/a/18160164
        for e in dom.getiterator():
            if not hasattr(e.tag, "find"):
                continue
            if e.tag.endswith("math"):
                continue
            i = e.tag.find('}')
            if i >= 0:
                e.tag = e.tag[i+1:]
        lo.deannotate(dom.getroot(), cleanup_namespaces=True)

    def fix_function_applications(dom, class_name, ns={}):
        functions = [str(x) for x in dom.xpath("/dae/functions/function/@name")]
        applies = dom.xpath("//mml:apply/*[1]", namespaces=ns)
        for app in applies:
            tag_name = et.QName(app).localname.replace("_dollar_", "$")
            if tag_name in functions:
                app.tag = et.QName(ns["mml"], "ci")
                app.text = tag_name

    def extract_variables(fname, xslt_dir="."):
        dom = et.parse(fname)
        vars = dom.xpath("//variable")
        result = []
        for v in vars:
            isalias = str(v.getparent().getparent().tag) == "aliasVariables"
            vdict = {
                "name": v.get("name"),
                "variability": v.get("variability"),
                "type": v.get("type"),
                "label": v.get("comment"),
                "quantity": v.xpath("string(attributesValues/quantity/@string)"),
                "unit": v.xpath("string(attributesValues/unit/@string)"),
                "initial": v.xpath("string(attributesValues/initialValue/@string)"),
                "bindExpression": v.xpath("string(bindExpression/@string)")
            }
            vdict["aliasof"] = vdict["bindExpression"] if isalias else None
            for k in vdict:
                if vdict[k] is None:
                    vdict[k] = ""
            # if len(vdict["bindExpression"]) > 0:
            #     vdict["bindExpression"] = c2p(vdict["bindExpression"], xslt_dir=xslt_dir)
            result.append(vdict)
        return result

    def c2p(content, xslt_dir="."):
        single = False
        if not isinstance(content, list):
            content = [content]
            single = True
        content_to_pres = load_ctop(xslt_dir)
        presentation = [content_to_pres(c) for c in content]
        for p in presentation:
            cleanup_mathml(p)
        if single:
            return presentation[0]
        else:
            return presentation

    def extract_equations(fname, xslt_dir="."):
        dom = et.parse(fname)
        ns = {"mml": "http://www.w3.org/1998/Math/MathML"}
        fix_function_applications(dom, os.path.splitext(os.path.basename(fname))[0], ns=ns)
        mathdoms = dom.xpath("/dae/equations/equation/MathML/mml:math", namespaces=ns)
        newdoms = c2p(mathdoms, xslt_dir=xslt_dir)
        return [et.tostring(x) for x in newdoms]

    def extract_functions(fname):
        dom = et.parse(fname)
        functions = dom.xpath("//function")
        res = []
        for f in functions:
            name = f.get("name")
            impl = f[0].text
            headi = impl.find("function " + name)
            head = impl[:headi]
            impl = impl[headi:]
            res.append([name, head, impl])
        return res
    """
end
