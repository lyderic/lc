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
	ocache = pblua("justfilesbackup.yml")
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
