unless String::trim
  String::trim = ->
    @replace /^\s+|\s+$/g, ""
unless Array.isArray
  Array.isArray = (vArg) ->
    Object::toString.call(vArg) is "[object Array]"
unless Array::indexOf
  Array::indexOf = (searchElement) -> #, fromIndex
    "use strict"
    throw new TypeError()  unless this?
    t = Object(this)
    len = t.length >>> 0
    return -1  if len is 0
    n = 0
    if arguments_.length > 1
      n = Number(arguments_[1])
      unless n is n # shortcut for verifying if it's NaN
        n = 0
      else n = (n > 0 or -1) * Math.floor(Math.abs(n))  if n isnt 0 and n isnt Infinity and n isnt -Infinity
    return -1  if n >= len
    k = (if n >= 0 then n else Math.max(len - Math.abs(n), 0))
    while k < len
      return k  if k of t and t[k] is searchElement
      k++
    -1
require.config
  paths:
    d3: "https://cdnjs.cloudflare.com/ajax/libs/d3/3.0.8/d3.min"

  shim:
    d3:
      exports: "d3"
