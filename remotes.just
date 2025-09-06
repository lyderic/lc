# list remotes
names:
	#!/usr/bin/env -S lua -llee
	data=json.decode(ea("incus remote list -fjson"))
	for remote,d in pairs(data) do
		if d.Protocol ~= "incus" or remote == "local" then goto nx end
		print(remote)
	::nx::end

# show devices
devices:
	#!/usr/bin/env -S lua -llee
	data=json.decode(ea("incus remote list -fjson"))
	for remote,d in pairs(data) do
		if d.Protocol ~= "incus" or remote == "local" then goto nxr end
		printf("\27[7m[%s] %s\27[m\n", remote, d.Addr)
		for name in e(f("incus names %s:", remote)):lines() do
			devices=ea(f("incus config device show %s:%s", remote, name))
			if devices == "{}\n" then goto nxn end
			printf("\27[1mname: %s:%s\27[m\n", remote, name)
			print(devices)
		::nxn::end
	::nxr::end

# vim: ft=just
