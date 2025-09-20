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
	check_key()
end

function check_key()
	local loadedgripscmd = "gpg-connect-agent 'keyinfo --list' /bye"
		.."| grep ' - 1 P ' | awk '{print$3}'"
	for loadedgrip in e(loadedgripscmd):lines() do
		local cmd = "gpg -k | grep -B2 "..loadedgrip
			.."| head -1 | awk '{print$3}'"
		local keyname = eo(cmd)
		if keyname == env("GPGKEY") then return end
	end
	print("\27[33mgpg key missing from agent's cache\27[m")
	--we force the key to be loaded to the agent:
	local dummy = os.tmpname()
	if not x(f("gpg -e -r %s %q", key, dummy)) then
		die("dummy crypt failed!")
	end
	local ok = x("gpg -d "..dummy..".gpg")
	os.remove(dummy);os.remove(dummy..".gpg")
	if not ok then die("gpg key loading failed!") end
end

function fetch()
	ocache = pblua("justfilesbackup.yml")
end

function envencrypt()
	local files = {}
	for file in e(f("find %q -name '.env*'", jdir)):lines() do
		if file:sub(-3) == "gpg" then goto nxt end
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
				os.remove(file)
				printf("\27[31merror encrypting file %q! file removed\n", file)
				goto nxt
			end
		else
			printf("\27[33m%q has same content as %q\27[m\n", gpgfile, file)
		end
		if os.remove(file) then print(file.." removed") end
	::nxt::end
	clean()
end

-- we don't want no unencrypted .env* file left
function clean()
	local cmd = f("find %q -type f -name '.env*' -not -name '*.gpg' -delete", env("JUSTFILES_REPOSITORY"))
	if not x(cmd) then
		die("cleaning failed!!! check no unencrypted .env* are left")
	end
end

main()
