alias h   := _help
alias cn  := cnames
alias an  := anames
alias ls  := names
alias st  := structure
alias s   := status
alias i   := info
alias gr  := groups
alias u   := connect-user
alias r   := ruser
alias rr  := rroot
alias rs  := reset
alias b   := justfiles-backup
alias ua  := machinesupdate
alias cz  := chezmoiupdate
alias reb := reboot

_help:
	@just --list --unsorted --alias-style left --color always \
		--list-heading='' --list-prefix=' ' \
		| sed -e 's/alias: //' | awk 'NF'

# list names
[group("reporting")]
names:
	@ansible "${t}" --list | awk 'NR>1 {print $1}'

# list names with remotes
[group("reporting")]
cnames *sep:
	#!/usr/bin/env -S lua -llee
	cmd = "ansible-inventory --list --limit '{{t}}'"
	data = json.decode(ea(cmd))
	chosts = {}
	for host,keys in pairs(data._meta.hostvars) do
		chost = host
		if keys.ansible_connection == "community.general.incus" then
			remote = keys.ansible_incus_remote or "local"
			chost = f("%s:%s", remote, host)
		end
		table.insert(chosts,chost)
	end
	sep = os.getenv("sep")
	if sep == "" then sep = "\n" end
	print(table.concat(chosts, sep))

# list names of hosts running Archlinux or $DISTRO
[group("reporting")]
anames *sep: _inventory_cache
	#!/usr/bin/env -S lua -llee
	cmd = "ansible-inventory --list --limit '{{t}}'"
	data = json.decode(ea(cmd))
	--fh = io.open(env("icache"));content = fh:read("a");fh:close()
	--data = json.decode(content)
	distro = env("DISTRO") or "Archlinux"
	distro_hosts = {}
	for host,keys in pairs(data._meta.hostvars) do
		if not keys.ansible_os_family then
			printf("\27[31mcannot scan %q. Skipping...\27[m", host)
			goto next
		end
		if keys.ansible_os_family.__ansible_unsafe == distro then
			table.insert(distro_hosts, host)
		end
	::next::end
	sep = os.getenv("sep")
	if sep == "" then sep = "\n" end
	print(table.concat(distro_hosts, sep))

# list groups
[group("reporting")]
groups: _inventory_cache
	#!/usr/bin/env -S lua -llee
	target = env("t")
	fh = io.open(env("icache"))
	data = json.decode(fh:read("a"));fh:close()
	for group in pairs(data) do
		if group == target then valid = true break end
	end
	if valid then
		x(f("ansible-inventory %q --graph | less -FRIX", target))
	else
		printf("\27[31m%q: not a valid group\27[m\n", target)
	end

# ping pong
[group("reporting")]
ping:
	@ansible-playbook "actions/ping.yml" -l "${t}"

# status vigilax reporting
[group("reporting")]
status:
	@lua ./scripts/status.lua

# show info 
[group("reporting")]
info:
	@lua ./scripts/info.lua

# operations on remotes
[group("reporting")]
mod remotes

# inventory structure
[group("reporting")]
structure: _inventory_cache
	#!/usr/bin/env -S lua -llee
	function wrap(t)
		local fold = e("fold -s","w")
		fold:write(table.concat(t," "));fold:close()
		print()
	end
	fh = io.open(env("icache"))
	data = json.decode(fh:read("a"));fh:close()
	io.write("\27[1mgroups:\27[m ")
	groups = {}
	for group in pairs(data) do
		if group == "_meta" or group == "all" then goto next end
		table.insert(groups, group)
	::next::end
	wrap(groups)
	io.write("\27[1mhosts:\27[m ")
	hosts = {}
	for host in pairs(data._meta.hostvars) do
		table.insert(hosts, host)
	end
	wrap(hosts)

# update packages
[group("actions")]
machinesupdate:
	@ansible-playbook -v "actions/machinesupdate.yml" -l "${t}"

# reboot
[group("actions")]
reboot:
	#!/bin/bash
	# it'd be unwise to reboot *all* the machines
	[ "${t}" == "all" ] && t=local
	ansible "${t}" -bm reboot

# update chezmoi
[group("actions")]
chezmoiupdate:
	#!/bin/bash
	blue "[updating chezmoi for user]"
	ansible "${t}" -a 'chezmoi update'
	blue "[updating chezmoi for root]"
	ansible "${t}" -ba 'chezmoi update'

# run <cmd> as user (operator)
[group("actions")]
ruser *cmd:
	@lua ./scripts/runcmd.lua "m" ${cmd}

# run <cmd> as root
[group("actions")]
rroot *cmd:
	@lua ./scripts/runcmd.lua "bm" ${cmd}

# run script as user (operator)
[group("actions")]
rscript:
	#!/bin/bash
	[ -f ~/.cache/vim/swap/%dev%shm%lc%lc_script.swp ] || {
		vim /dev/shm/lc/lc_script
		chmod +x /dev/shm/lc/lc_script
	}
	lua ./scripts/rscript.lua | less -FRIX

# connect as uid 1000
[group("actions")]
connect-user *host: _inventory_cache
	#!/usr/bin/env -S lua -llee
	host = "{{host}}"
	fh = io.open(env("icache"))
	data = json.decode(fh:read("a"));fh:close()
	allhosts = {}
	if host == '' then
		for h in pairs(data._meta.hostvars) do
			table.insert(allhosts, h)
		end
		host = eo(f('echo "%s" | fzf', table.concat(allhosts, "\n")))
	end
	if not host or host == '' then print("no host") os.exit(122) end
	for h,d in pairs(data._meta.hostvars) do
		if h == host then remote = d.ansible_incus_remote end
	end
	if remote then
		x(f("incus exec %s:%s -- su - unix", remote, host))
	else
		x("ssh "..host)
	end

# backup justfiles, .aqui and .env
[group("actions")]
justfiles-backup:
	@lua scripts/justfilesbackup.lua

# remove cached facts and ansible outputs
[group("actions")]
reset:
	rm -rvf /tmp/ansible* /dev/shm/lc*

_inventory_cache:
	#!/bin/bash
	[ -f "${icache}" ] && exit 0
	echo -ne "\e[90mbuilding inventory cache...\e[m" > /dev/stderr
	ansible all -m setup -f 32 >/dev/null 
	ansible-inventory --list --output "${icache}"
	echo -ne "\r\e[K"
 
# run coc, possibly with password
[group("actions")]
coc:
	#!/bin/bash
	[ "${t}" == "all" ] && t=coc
	COCKEY=$(pass luks/usbdrives)
	#ansible "${t}" -m shell -a "bash -c 'source ~/.bigbang ; export KEY=${COCKEY} && coc'"
	#ansible "${t}" -m shell -a "KEY=${COCKEY} coc"
	lc ="${t}" ruser "KEY=${COCKEY} coc"

_init:
	#!/bin/bash
	[ -e /tmp/ansible_facts/${t} ] && exit 0
	echo -ne "\e[2mgathering facts, please wait...\e[m"
	export ANSIBLE_STDOUT_CALLBACK=community.general.null
	ansible-playbook "actions/init.yml" -l "${t}"
	echo -ne "\r\e[K"

_completion:
	@just --summary

#test:
#	@lua scripts/test.lua

[private]
v:
	just --evaluate

t := "all"

acache := "/tmp/ansible_facts"
icache := "/tmp/ansible-inventory-cache.json"

LUA_PATH := env("LUA_PATH") + ";" + "scripts/?.lua"
LC_PLAYBOOKS_DIR := justfile_directory() / "actions"
LC_SCRIPTS_DIR := justfile_directory() / "scripts"

# Set these variables in .env file. They are mandatory
JUSTFILES_REPOSITORY := env("JUSTFILES_REPOSITORY", "--unset--")
GPGKEY := env("GPGKEY", "--unset--")

set dotenv-required
set export
set shell := ["bash","-uc"]
# vim: ft=just
