require "lee"

-- global constants
lcluaversion = "20250725-0"
lccache = "/dev/shm/lc"
width = eo("tput cols")

-- environment variables
-- this lib is used by scripts that are called from 'lc', i.e. a
-- justfile that should always provide 'target'
-- run: 'lc v'
target = os.getenv("t") or "--unset--"
pbdir = env("LC_PLAYBOOK_DIR") or "--unset--"
scriptsdir = env("LC_SCRIPTS_DIR") or "--unset--"

-- get vigilax and facts as a lua table
function vigifacts()
	ansibleplay("vigilax.yml")
	local ocache = {}
	for host in e("ls /dev/shm/lc/viou"):lines() do
		local fh = io.open("/dev/shm/lc/viou/"..host)
		local data = json.decode(fh:read("a")) fh:close()
		ocache[host] = data
	end
	return ocache
end

function ansibleplay(pbook)
	local path = pbdir.."/"..pbook
	x(f("ansible-playbook %q -l %q", path, target))
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
