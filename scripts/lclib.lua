require "lee"

-- global constants
lcluaversion = "20250830-0"
lccache = "/dev/shm/lc"
width = tonumber(eo("tput cols")) or 80

-- environment variables
-- this lib is used by scripts that are called from 'lc', i.e. a
-- justfile that should always provide 'target'
-- run: 'lc v'
target = os.getenv("t") or "--unset--"
pbdir = env("LC_PLAYBOOKS_DIR") or "--unset--"

-- make sure lccache directory is created, always
x("mkdir -pv "..lccache)

-- run a playbook, get output as json.
-- if envar "DEBUG" is set, then output is also saved to lccache
function pbjson(pbook)
	io.stderr:write(f("\27[2mplaying %q on target %q, please wait...",
		pbook, target))
	local path = f("%s/%s", pbdir, pbook)
	local callback = "ANSIBLE_STDOUT_CALLBACK=ansible.posix.json"
	local cmd = f("%s ansible-playbook %q -l %q",
		callback,
		path,
		target)
	local jsonoutput = ea(cmd)
	if env("DEBUG") then
		local fh = io.open(f("%s/%s", lccache, pbook..".json"), "w")
		fh:write(jsonoutput) fh:close()
	end
	io.stderr:write("\r\27[K\27[m")
	return jsonoutput
end

-- run a playbook, get output as a lua table
function pblua(pbook)
	return json.decode(pbjson(pbook))
end

-- ansible command line run. definition is a lua table like e.g. this:
-- definition = {
-- 	mode = "m" -- 'bm' if run as root
-- 	module = "shell",
-- 	args = "uptime --pretty",
-- 	output = "/path/to/dir", -- where json files will go
-- 	verbose = false,
-- }
function ansible(d)
	os.execute("rm -rf "..d.output) -- always reset cached data
	d.mode = d.mode or "m" -- default is to run as operator, not root
	d.module = d.module or "command" -- same default as ansible cli
	local cmd = f("ansible %q -%s %q -a %q -t %q",
		target, d.mode, d.module, d.args, d.output)
	if not verbose then cmd = cmd.." >/dev/null 2>&1" end
	return x(cmd)
end

function get_vigilax()
	local ocache = pblua("vigilax.yml")
	local hosts = ocache.plays[1].tasks[1].hosts
	if not hosts then print("no hosts!") return nil end
	local valid_hosts = {}
	for host, data in pairs(hosts) do
		if data.unreachable or not data.changed then
			printf("\27[31m%s unreachable or vigilax failed!\27[m\n",
				host)
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
		valid_hosts[host] = m
	::next::end
	return valid_hosts
end

function header(message, decoration)
	if tonumber(width) > 99 then width = 99 end
	if not decoration then decoration = "\27[1;7m" end
	printf(decoration.."%-"..width.."."..width.."s\27[m\n", message)
end

function die(message)
	print("\27[31m"..message.."\27[m")
	os.exit(42)
end
