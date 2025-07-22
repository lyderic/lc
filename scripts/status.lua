#!/usr/bin/env -S lua -llee -W

-- include lclib
local curdir = eo(f("dirname %q", arg[0]))
package.path = package.path..";"..curdir.."/?.lua"
require "lclib"

function main()
	io.write("\27[2mrunning ansible to ")
	printf("get vigilax data from target %q, please wait...", target)
	io.flush()
	local ocache = ansiblevigilax()
	io.write("\r\27[K\27[m")
	report(ocache)
end

function report(ocache)
	local n = 0
	local mut, mup = 30, 10
	for host, m in pairs(ocache) do
		n = n + 1
		if m.secondsup > mut*24*3600 then
			printf("%s uptime: %s\n", host, m.uptime)
		end
		if m.updates > mup then
			printf("%s updates: %d\n", host, m.updates)
		end
		if m.reboot == true then
			printf("reboot due on %s\n", host)
		end
		if m.loadavg > (m.nproc / 2) then
			printf("One minute load average is > %d on %s\n",
				(m.nproc / 2), host)
		end
	end
	printf("\27[2;33m%d host%s processed\27m\n", n, n > 1 and "s" or "")
end

function usage()
	print([[Usage: status.lua [-h] [-t <target>]
  -h          this help
  -t <target> specify target (default: all)]])
end

main()
