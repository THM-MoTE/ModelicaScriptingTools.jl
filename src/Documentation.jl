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

function getvariables(omc:: OMCSession, model::String)
    res = sendExpression(omc, "dumpXMLDAE($model, addMathMLCode=true)")
    err = sendExpression(omc, "getErrorString()")
    if !isempty(err)
        throw(MoSTError("Could not save model as independent XML file", err))
    end
    res = py"extract_variables"(res[2], xslt_dir=joinpath(@__DIR__, "..", "res"))
    return res
end

function variabletable(vars:: Array{Dict{Any, Any},1})
    header = """
    |name|unit|value|label|
    |----|----|-----|-----|
    """
    lines = []
    for v in vars
        value = if isnothing(v["initial"])
            v["bindExpression"]
        else
            v["initial"]
        end
        vals = [v["name"], v["unit"], value, v["label"]]
        push!(lines, "|$(join(vals, "|"))|")
    end
    table = "$(header)$(join(lines, "\n"))"
    println(table)
    return Markdown.parse(table)
end

# extend Documenter with new code block type @modelica
abstract type ModelicaBlocks <: Documenter.Expanders.ExpanderPipeline end
Documenter.Selectors.order(::Type{ModelicaBlocks}) = 5.0
Documenter.Selectors.matcher(::Type{ModelicaBlocks}, node, page, doc) = Documenter.Expanders.iscode(node, "@modelica")
function Documenter.Selectors.runner(::Type{ModelicaBlocks}, x, page, doc)
    lines = Documenter.Utilities.find_block_in_file(x.code, page.source)
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
                        htmleqs = "<ol><li>$(join(equations, "\n<li>"))</ol>"
                        push!(result, Documenter.Documents.RawHTML(htmleqs))
                        vartab = variabletable(getvariables(omc, model))
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

    def fix_function_names(dom, ns={}):
        functions = [str(x) for x in dom.xpath("/dae/functions/function/@name")]
        applies = dom.xpath("//mml:apply/*[1]", namespaces=ns)
        for app in applies:
            tag_name = et.QName(app).localname.replace("_dollar_", "$")
            if tag_name in functions:
                app.tag = et.QName(ns["mml"], "ci")
                # use dot in output to not confuse MathJax
                app.text = tag_name.replace("$", ".")

    def extract_variables(fname, xslt_dir="."):
        dom = et.parse(fname)
        vars = dom.xpath("//variable")
        result = []
        for v in vars:
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
            for k in vdict:
                if vdict[k] is not None and len(vdict[k]) == 0:
                    vdict[k] = None
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
        fix_function_names(dom, ns=ns)
        mathdoms = dom.xpath("/dae/equations/equation/MathML/mml:math", namespaces=ns)
        newdoms = c2p(mathdoms, xslt_dir=xslt_dir)
        return [et.tostring(x) for x in newdoms]
    """
end
