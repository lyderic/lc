require "lclib"

local n = 0
local mut, mup = 30, 10
for host, m in pairs(get_vigilax()) do
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
local summary = f("%d host%s processed", n, n > 1 and "s" or "")
if env("NOCOLOR") then
	print(summary)
else
	print("\27[2;33m"..summary.."\27m")
end
