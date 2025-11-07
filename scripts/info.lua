require "lclib"

lines = { "Host,uproc,Distribution,Updates,Uptime,Avg" }
for host, m in pairs(get_vigilax()) do
	table.insert(lines, f([["%s","%s","%s","%s,%s,%s"]],
		host, m.nproc,m.distro, m.updates,
		m.uptime, m.loadavg))
end

x(f([[echo "%s" | xan view -pIM]], table.concat(lines, "\n")))
