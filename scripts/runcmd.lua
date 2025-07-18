#!/usr/bin/env -S lua -llee -W

local taco = table.concat

-- constants
local dir = "/dev/shm/oneout"

function init()
	x("rm -rf "..dir)
end

function main()
	init()
	local target, mode = arg[1], arg[2]
	local t = {}
	table.move(arg, 3, #arg, 1, t)
	local ansible = f("ansible %q -%s shell -a '%s' -t %q",
		target, mode, taco(t, " "), dir)
	execansible(ansible)
	display()
end

function execansible(ansible)
	io.write("\27[2;36mrunning, please wait...\27[m") io.flush()
	x(ansible.." >/dev/null 2>&1")
	io.write("\r\27[K")
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
