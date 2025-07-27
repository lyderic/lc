require "lee"

-- global constants
lcluaversion = "20250725-0"
lccache = "/dev/shm/lc"
width = tonumber(eo("tput cols"))

-- environment variables
-- this lib is used by scripts that are called from 'lc', i.e. a
-- justfile that should always provide 'target'
-- run: 'lc v'
target = os.getenv("t") or "--unset--"
pbdir = env("LC_PLAYBOOKS_DIR") or "--unset--"

-- make sure lccache directory is created, always
x("mkdir -pv "..lccache)

-- get vigilax and facts as a lua table
function vigifacts()
	local dir = f("%s/%s", lccache, "vigifacts")
	x(f("rm -rf %s/*", dir))
	ansibleplay("vigifacts.yml")
	local ocache = {}
	for host in e("ls "..dir):lines() do
		local fh = io.open(f("%s/%s", dir, host))
		local data = json.decode(fh:read("a")) fh:close()
		ocache[host] = data
	end
	return ocache
end

function ansibleplay(pbook)
	local path = f("%s/%s", pbdir, pbook)
	x(f("ansible-playbook %q -l %q", path, target))
end

-- run a playbook, get output as json.
-- if envar "DEBUG" is set, then output is also saved to lccache
function pbjson(pbook)
	io.stderr:write(f("\27[2mplaying %q on target %q, please wait...",
		pbook, target))
	local path = f("%s/%s", pbdir, pbook)
	local outplug = "ANSIBLE_STDOUT_CALLBACK=ansible.posix.json"
	local cmd = f("%s ansible-playbook %q -l %q",
		outplug,
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

-- run 'vigilax' on hosts and return a lua table of concatenated json
function ansiblevigilax()
	local def = {} -- definition table to pass to ansible() function
	def.output = lccache.."/vigilax"
	def.args = "~{{ operator }}/.justfile.d/vigilax.lua"
	ansible(def)
	local ocache = {}
	for host in e("ls "..def.output):lines() do
		local path = def.output.."/"..host
		local fh = io.open(path)
		local data = json.decode(fh:read("*a")) fh:close()
		local info = json.decode(data.stdout)
		ocache[host] = info
	end
	return ocache
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
	d.mode = d.mode or "m" -- default is to as operator, not root
	d.module = d.module or "command" -- same default as ansible cli
	local cmd = f("ansible %q -%s %q -a %q -t %q",
		target, d.mode, d.module, d.args, d.output)
	if not verbose then cmd = cmd.." >/dev/null 2>&1" end
	return x(cmd)
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
