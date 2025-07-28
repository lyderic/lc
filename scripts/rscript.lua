require "lclib"

function main()
	if not abs("/dev/shm/lc/lc_script") then
		fail("lc_script file not found!")
	end
	local ocache = pblua("rscript.yml")
	local hosts = ocache.plays[1].tasks[2].hosts
	for host,data in pairs(hosts) do
		local result = f("%s [rc=%d]", host, data.rc)
		header(result, "\27[4;97m")
		for i,line in ipairs(data.stdout_lines) do
			printf(" [O:%02d] \27[32m%s\27[m\n", i, line)
		end
		for i,line in ipairs(data.stderr_lines) do
			printf(" [E:%02d] \27[31m%s\27[m\n", i, line)
		end
	end
	-- background cleaning
	x(f("ansible-runner start %q -m file -a 'path=/dev/shm/lc_script state=absent' --hosts %q -i cleaning_lc_script --json", lccache, target))
end

main()
