require "lclib"

lines = { "Host,uproc,Distribution,Updates,Uptime,Avg" }
for host, m in pairs(get_vigilax()) do
	table.insert(lines, f([["%s","%s","%s","%s","%s","%s"]],
		host, m.nproc,m.distro, m.updates,
		m.uptime, m.loadavg))
end

output = table.concat(lines, "\n")
xan = e("xan view -pIM","w")
xan:write(output)
xan:close()
