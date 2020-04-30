# MOdelica Scripting Tools (MoST)

This project contains utility functions to improve the usability of OMJulia and OMPython.

## Usage

Currently, you have to download/clone this repository and import the modules locally to use them in your projects.
In the future, I may split up MoST into a MoST.jl and a pyMoST package which can be installed through pip and Pkg respectively.

### Julia

* Use `git clone https://github.com/THM-MoTE/MoST.git` to clone the repository or [download the current version of MoST as a zip archive](https://github.com/THM-MoTE/MoST/archive/master.zip).
* Alternatively, if your project is in a git repository and you want to add MoST permanently as a dependency, use `git submodule add --depth shallow https://github.com/THM-MoTE/MoST.git` to add MoST as a submodule into your repository and update it with `git submodule update --init`.
* In your Julia script where you want to use MoST functions, use
    ```julia
    import("MoST/src/julia/MoST.jl")
    using .MoST
    ```
