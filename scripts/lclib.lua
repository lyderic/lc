-- global constants
lcluaversion = "20250722-0"
lccache = "/dev/shm/lc"
width = eo("tput cols")

-- environment variables
-- these lib is used by scripts that are called from 'lc', i.e. a
-- justfile that should always provide 'target'
-- run: 'lc v'
target = os.getenv("t") or "--unset--"

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

function header(message, ansicolor)
	if not ansicolor then ansicolor = "\27[1;7m" end
	printf(ansicolor.."%-"..width.."."..width.."s\27[m", message)
end

function die(message)
	print("\27[31m"..message.."\27[m")
	os.exit(42)
end
