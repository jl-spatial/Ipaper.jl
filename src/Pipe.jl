# Copyright (c) 2015: Lyndon White.
# Reference: 
# 1. https://github.com/oxinabox/Pipe.jl/blob/master/src/Pipe.jl
# This function is modified from Lyndon White (2015), with the MIT License.

module Pipe
#Reflow piped things replacing the _ in the next section

const PLACEHOLDER = :_

function replace(arg::Any, target)
  arg #Normally do nothing
end

function replace(arg::Symbol, target)
  if arg == PLACEHOLDER
    target
  else
    arg
  end
end

function replace(arg::Expr, target)
  rep = copy(arg)
  rep.args = map(x -> replace(x, target), rep.args)
  rep
end

find_underscores(x::Any) = false
find_underscores(x::Symbol) = x == :_
function find_underscores(x::Expr)
  map(find_underscores, x.args) |> any
end

function rewrite(ff::Expr, target)
  # @show ff.args
  # dump(ff.args)
  # check underscores; if not found, insert to the first position
  _found = find_underscores(ff)

  if !_found
    agrs = ff.args
    if typeof(ff.args[2]) == LineNumberNode
      ff.args = [agrs[1:2]..., :_, agrs[3:end]...]
    else
      ff.args = [agrs[1], :_, agrs[2:end]...]
    end
  end
  # dump(ff.args)

  rep_args = map(x -> replace(x, target), ff.args)
  if ff.args != rep_args
    #_ subsitution
    ff.args = rep_args
    return ff
  end

  #No subsitution was done (no _ found)
  #Apply to a function that is being returned by ff,
  #(ff could be a function call or something more complex)
  rewrite_apply(ff, target)
end

function rewrite_broadcasted(ff::Expr, target)
  temp_var = gensym()
  rep_args = map(x -> replace(x, temp_var), ff.args)
  if ff.args != rep_args
    #_ subsitution
    ff.args = rep_args
    return :($temp_var -> $ff)
  end

  #No subsitution was done (no _ found)
  #Apply to a function that is being returned by ff,
  #(ff could be a function call or something more complex)
  rewrite_apply_broadcasted(ff, target)
end

function rewrite_apply(ff, target)
  :($ff($target)) #function application
end

function rewrite_apply_broadcasted(ff, target)
  temp_var = gensym()
  :($temp_var -> $ff($temp_var))
end

function rewrite(ff::Symbol, target)
  if ff == PLACEHOLDER
    target
  else
    rewrite_apply(ff, target)
  end
end

function rewrite_broadcasted(ff::Symbol, target)
  if ff == PLACEHOLDER
    target
  else
    rewrite_apply_broadcasted(ff, target)
  end
end

function funnel(ee::Any) #Could be a Symbol could be a literal
  ee #first (left most) input
end

function funnel(ee::Expr)
  if (ee.args[1] == :|>)
    target = funnel(ee.args[2]) #Recurse
    rewrite(ee.args[3], target)
  elseif (ee.args[1] == :.|>)
    target = funnel(ee.args[2]) #Recurse
    rewritten = rewrite_broadcasted(ee.args[3], target)
    ee.args[3] = rewritten
    ee
  else
    #Not in a piping situtation
    ee #make no change
  end
end

macro pipe(ee)
  esc(funnel(ee))
end

export @pipe
end
