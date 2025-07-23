#!/usr/bin/env -S lua -llee -W

-- include lclib
local curdir = eo(f("dirname %q", arg[0]))
package.path = package.path..";"..curdir.."/?.lua"
require "lclib"

-- directory where output of command will go
local dir = lccache.."/runcmd"

function main()
	local mode = arg[1]
	if not mode == "m" or not mode == "bm" then
		die("--runcmd-- invalid mode: %q", mode)
	end
	local t = {}
	table.move(arg, 2, #arg, 1, t)
	local definition = {
		mode = mode,
		module = "shell",
		args = table.concat(t, " "),
		output = dir,
	}
	io.write("\27[2;36mrunning, please wait...\27[m") io.flush()
	ansible(definition)
	io.write("\r\27[K")
	display()
end

function display()
	local all = {}
	local multi = false
	for host in e("ls "..dir):lines() do
		local combined = {}
		combined.host = host
		local fh = io.open(dir.."/"..host)	
		local data = json.decode(fh:read("a")) fh:close()
		combined.lines = extract_and_colorize(data)
		if #combined.lines > 1 then multi = true end
		table.insert(all, combined)
	end
	if multi then display_multiline(all) else display_oneline(all) end
end

function display_multiline(inputs)
	for _,input in ipairs(inputs) do
		header(input.host, "\27[1;4;97m")
		print(table.concat(input.lines, "\n"))
	end
end

function display_oneline(inputs)
	-- computing longest host name
	local max = 0
	for _,input in ipairs(inputs) do
		local n = string.len(input.host)
		if n > max then max = n end
	end
	local hformat = "\27[1m%-"..max.."."..max.."s\27[m : "
	for _,input in ipairs(inputs) do
		printf(hformat, input.host)
		print(input.lines[1])
	end
end

function extract_and_colorize(data)
	local combined_lines = {}
	for _,line in ipairs(data.stdout_lines) do
		table.insert(combined_lines, "\27[32m"..line.."\27[m")
	end
	for _,line in ipairs(data.stderr_lines) do
		table.insert(combined_lines, "\27[31m[ERR] "..line.."\27[m")
	end
	return combined_lines
end

main()
