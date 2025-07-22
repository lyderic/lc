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
	hosts = {}; max = 0
	for host in e("ls "..dir):lines() do
		local n = string.len(host)
		if n > max then max = n end
		table.insert(hosts, host)
	end
	hformat = "\27[1m%-"..max.."."..max.."s\27[m : "
	for _, host in ipairs(hosts) do
		fh = io.open(dir.."/"..host)	
		data = json.decode(fh:read("a")) fh:close()
		printf(hformat, host)
		firsto,firste = data.stdout_lines[1],data.stderr_lines[1]
		if firsto then printf("\27[32m%s\27[m", firsto) end
		if firste then printf("\27[31m%s\27[m", firste) end
		print()
	end
end

main()
