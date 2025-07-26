require "lclib"

function main()
	local ocache = vigifacts()
	report(ocache)
end

function report(ocache)
	print("LC REPORT "..string.rep("*", width - 10))
	local n = 0
	local mut, mup = 30, 10
	for host, data in pairs(ocache) do
		local m = data.vigilax
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
	printf("\27[33m%d host%s processed\27m\n", n, n > 1 and "s" or "")
end

main()
