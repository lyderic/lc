require "lclib"

function main()
	local ocache = pblua("vigilax.yml")
	report(ocache.plays[1].tasks[1].hosts)
end

function report(hosts)
	if not hosts then print("no hosts!") return end
	local n = 0
	local mut, mup = 30, 10
	for host, data in pairs(hosts) do
		if data.unreachable or not data.changed then
			printf("\27[31m%s unreachable or vigilax failed!\27[m\n", host)
			goto next
		end
		if env("DEBUG") == "true" then
			print("\27[7m"..host.."\27[m")
		end
		local m = json.decode(data.stdout)
		if env("DEBUG") == "true" then
			dump(m)
		end
		if not m then
			printf("\27[31mno vigilax data for %s!\27[m\n", host)
			goto next
		end
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
	::next::end
	local summary = f("%d host%s processed", n, n > 1 and "s" or "")
	if env("NOCOLOR") then
		print(summary)
	else
		print("\27[2;33m"..summary.."\27m")
	end
end

main()
