require "lclib"

function main()
	local ocache = pblua("test.yml")
	--for _,play in ipairs(ocache.plays) do
		local play = ocache.plays[1]
		printf("--- PLAY=[%s] ---\n", play.play.name)
		for _,task in ipairs(play.tasks) do
			printf("> TASK=[%s] -----------------\n", task.task.name)
			for host,data in pairs(task.hosts) do
				process(host,data)
			end
		end
	--end
end

function process(host,data)
	header(host,"\27[1;42;96m")
	dump(data)
end

main()
