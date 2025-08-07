require "lclib"

function main()
	init()
	fetch()
	envencrypt()
end

function init()
	for _,var in ipairs{"JUSTFILES_REPOSITORY","GPGKEY"} do
		if not env(var) then die(var.." not found!") end
		if env(var) == "--unset--" then
			die(var.." is not set!")
		end
	end
	jdir, key = env("JUSTFILES_REPOSITORY"), env("GPGKEY")
end

function fetch()
	local ocache = {}
	local cache = "/dev/shm/lc/justfilesbackup.yml.json"
	if abs(cache) then
		printf("\27[33musing debug cache %q\n", cache)
		local fh = io.open(cache)
		ocache = json.decode(fh:read("a")) fh:close()
	else
		ocache = pblua("justfilesbackup.yml")
	end
	local tasks = ocache.plays[1].tasks -- there's only one play
	for n,task in ipairs(tasks) do
		local name = task.task.name
		if name == "FetchJustfile" then hFetchJustfile = task.hosts
		elseif name == "FetchAqui" then hFetchAqui = task.hosts
		elseif name == "FetchEnv" then hFetchEnv = task.hosts end
	end
	for host,m in pairs(ocache.stats) do
		local changes = {}
		if hFetchJustfile[host].changed then
			table.insert(changes, "justfile")
		end
		if hFetchAqui[host].changed then
			table.insert(changes, ".aqui")
		end
		if not hFetchEnv[host].skipped then
			local gpgfile = f("%s/%s/.env.gpg",
				env("JUSTFILES_REPOSITORY"), host)
			if abs(gpgfile) then
				local denvsum = hFetchEnv[host].md5sum
				local eenvsum = eo(f("gpg -d %q | md5sum | awk '{print$1}'",
					gpgfile))
				if denvsum ~= eenvsum then
					table.insert(changes, ".env")
				end
			else
				table.insert(changes, ".env")
			end
		end
		if #changes > 0 then
			printf("%s: %s\n", host, table.concat(changes, " "))
		end
	::next:: end
	--[[
	for host,m in pairs(ocache.stats) do
		printf("%-10.10s: ", host)
		for k,v in pairs(m) do printf("%s:%d ", k, v) end
		print()
	end
	--]]
end

function envencrypt()
	local files = {}
	for file in e(f("find %q -name .env", jdir)):lines() do
		local flag = true
		local gpgfile = file..".gpg"
		if abs(gpgfile) then
			printf("\27[35mfound %s\27[m\n", gpgfile)
			local esum = eo(f("gpg -d %q | md5sum", gpgfile))
			local dsum = eo(f("cat %q | md5sum", file))
			if esum == dsum then flag = false end
		end
		if flag then
			if x(f("gpg -e -r %s %q", key, file)) then
				printf("\27[32m%s encrypted\n", file)
			else
				die("error encrypting file "..file)
			end
		else
			printf("\27[33m%q has same content as %q\27[m\n", gpgfile, file)
		end
		if os.remove(file) then print(file.." removed") end
	end
end

main()
