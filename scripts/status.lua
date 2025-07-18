#!/usr/bin/env -S lua -llee -W

-- constants
cachettl = 60*60 -- minutes*seconds
basedir = "/dev/shm/vigilax"
cachedir = basedir.."/cache"
ocache = {} -- objects cache
target = "all" -- default target

function main()
	local opts = getopt("t")
	if opts.h then usage() return end
	target = opts.t and opts.t or target
	cache()
	report()
end

function cache()
	ansiblevigilax()
	for host in e("ls "..cachedir):lines() do
		local path = cachedir.."/"..host
		local fh = io.open(path)
		local data = json.decode(fh:read("*a")) fh:close()
		local info = json.decode(data.stdout)
		ocache[host] = info
	end
end

function ansiblevigilax()
	x(f("rm -rf %s/*", cachedir))
	printf("\27[2;36mrunning ansible on target %q...\27[m\n", target)
	io.flush()
	local luaprog = "~{{ operator }}/.justfile.d/vigilax.lua"
	local cmd = f("ansible %q -a %q -t %q", target, luaprog, cachedir)
	x(cmd)
end

function report()
	local n = 0
	local mut, mup, mts = 30, 10, cachettl
	for host, m in pairs(ocache) do
		n = n + 1
		if m.secondsup > mut*24*3600 then
			printf("%s uptime: %s\n", host, m.uptime)
		end
		if m.updates > mup then
			printf("%s updates: %d\n", host, m.updates)
		end
		local over = os.time() - m.timestamp - mts
		if over > 0 then
			local ttlsec = cachettl / 60
			printf("%s status is more than %.0f minute%s old (%ds over)\n",
				host, ttlsec, ttlsec > 1 and "s" or "", over)
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
