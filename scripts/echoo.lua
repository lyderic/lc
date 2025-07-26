require "lclib"

function main()
	--vigilaxprocess(pblua("vigilax.yml"))
	--pingprocess(pblua("ping.yml"))
	pbjson("vigifacts.yml")
end

function vigilaxprocess(ocache)
	for _,play in ipairs(ocache.plays) do
		for _,task in ipairs(play.tasks) do
			for host, data in pairs(task.hosts) do
				header(host, "\27[97;45m")
				local o = json.decode(data.stdout)
				for _,item in ipairs{ o.updates, o.uptime, o.reboot } do
					if item then print(">", type(item), item) end
				end
			end
		end
	end
end

function pingprocess(ocache)
	for host,data in pairs(ocache.plays[1].tasks[1].hosts) do
		print(host, ":", data.ping)
	end
end

main()
