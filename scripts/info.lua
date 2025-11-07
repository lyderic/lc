require "lclib"

function main()
	local ocache = pblua("vigilax.yml")
	report(ocache.plays[1].tasks[1].hosts)
end

function report(hosts)
	if not hosts then print("no hosts!") return end
	lines = { "Host,uproc,Distribution,Updates,Uptime,Avg" }
	for host,data in pairs(hosts) do
		if data.unreachable or not data.changed then
			printf("\27[31m%s unreachable or vigilax failed!\27[m\n", host)
			goto next
		end
		if env("DEBUG") == "true" then
			print("\27[7m"..host.."\27[m")
		end
		info = json.decode(data.stdout)
		if env("DEBUG") == "true" then
			dump(info)
		end
		if not info then
			printf("\27[31mno vigilax data for %s!\27[m\n", host)
			goto next
		end
		table.insert(lines, f([["%s","%s","%s","%s,%s,%s"]],
			host, info.nproc,info.distro, info.updates,
			info.uptime, info.loadavg))
	::next::end
	x(f([[echo "%s" | xan view -pIM]], table.concat(lines, "\n")))
end

main()
