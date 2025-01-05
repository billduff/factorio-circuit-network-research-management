debug = false

function debug_print(string)
  if debug then
    game.print(string, { skip = defines.print_skip.never })
  end
end
