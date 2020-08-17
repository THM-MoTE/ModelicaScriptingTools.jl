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
        modeldir = "../.."
        # get list of models and directory
        for (line) in split(x.code, '\n')
            if startswith(line, '%')
                try
                    modeldir = match(r"%\s*modeldir\s*=\s*(.*)", line).captures[1]
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
            outdir = joinpath(modeldir, "../out")
            withOMC(outdir, modeldir) do omc
                for (model) in modelnames
                    # load model without all extra checks
                    loadModel(omc, model; ismodel=false)
                    # get documentation as HTML string
                    htmldoc = getDocAnnotation(omc, model)
                    push!(result, Documenter.Documents.RawHTML(htmldoc))
                    # get model code
                    rawcode = getcode(omc, model)
                    push!(result, Documenter.Utilities.mdparse("```modelica\n$rawcode\n```\n"))
                    # get model equations
                    equations = getequations(omc, model)
                    htmleqs = "<ol><li>$(join(equations, "\n<li>"))</ol>"
                    push!(result, Documenter.Documents.RawHTML(htmleqs))
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

    def extract_equations(fname, xslt_dir="."):
        dom = et.parse(fname)
        ns = {"mml": "http://www.w3.org/1998/Math/MathML"}
        mathdoms = dom.xpath("/dae/equations/equation/MathML/mml:math", namespaces=ns)
        content_to_pres = load_ctop(xslt_dir)
        newdoms = [content_to_pres(x) for x in mathdoms]
        for x in newdoms:
            cleanup_mathml(x)
        return [et.tostring(x) for x in newdoms]
    """
end
