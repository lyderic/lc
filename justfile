alias h   := _help
alias ls  := names
alias s   := status
alias i   := info
alias cn  := cnames
alias gr  := groups
alias u   := connect-user
alias r   := ruser
alias rr  := rroot
alias rs  := reset
alias b   := backup-justfiles
alias ua  := machinesupdate
alias cz  := chezmoiupdate
alias reb := reboot

_help:
	@just --list --unsorted --alias-style left --color always \
		--list-heading='' --list-prefix=' ' \
		| sed -e 's/alias: //'

# list names
[group("reporting")]
names:
	@ansible "${t}" --list | awk 'NR>1 {print $1}'

# list names with remotes
[group("reporting")]
cnames: _init
	#!/usr/bin/env -S lua -llee
	data = json.decode(ea("ansible-inventory --list --limit ${t}"))
	for host,keys in pairs(data._meta.hostvars) do
		fh = io.open("/tmp/ansible_facts/"..host)
		local details = json.decode(fh:read("*a")) ; fh:close()
		local chost = host
		if keys.ansible_connection == "community.general.incus" then
			remote = keys.ansible_incus_remote or "local"
			chost = f("%s:%s", remote, host)
		end
		print(chost)
	end

# list groups
[group("reporting")]
groups:
	#!/usr/bin/env -S lua -llee
	target = env("t")
	data = json.decode(ea("ansible-inventory --list"))
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
	@./scripts/status.lua

# show info 
[group("reporting")]
info:
	#!/usr/bin/env -S lua -llee
	require "lclib"
	ins = table.insert
	io.write("\27[2macquiring vigilax data from ")
	printf("target %q, please wait...", target) ; io.flush()
	ocache = ansiblevigilax()
	io.write("\r\27[K\27[m") ; io.flush()
	lines = { "Host,Nproc,Distribution,Updates,Uptime,Avg" }
	for host,info in pairs(ocache) do
		ins(lines, f([["%s","%s","%s","%s,%s,%s"]],
			host, info.nproc,info.distro, info.updates,info.uptime, info.loadavg)
		)
	end
	x(f([[echo "%s" | xan view -pIM]], table.concat(lines, "\n")))

# update packages
[group("actions")]
machinesupdate:
	@ansible-playbook -v "actions/machinesupdate.yml" -l "${t}"

# reboot
[group("actions")]
reboot:
	@ansible "${t}" -bom reboot

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
	@./scripts/runcmd.lua "m" ${cmd}

# run <cmd> as root
[group("actions")]
rroot *cmd:
	@./scripts/runcmd.lua "bm" ${cmd}

# connect as uid 1000
[group("actions")]
connect-user host:
	#!/usr/bin/env -S lua -llee
	x("lc ='{{host}}' _init")
	fh = io.open("/tmp/ansible_facts/{{host}}")
	if not fh then print("\27[31minvalid host!\27[m") os.exit(1) end
	data = json.decode(fh:read("*a"))
	fh:close()
	vtype = data.ansible_virtualization_type
	if vtype == "lxc" then
		x(f("incus exec %s -- su - unix", eo("lc t={{host}} cnames")))
	else
		x("ssh {{host}}")
	end

# run coc, possibly with password
[group("actions")]
coc:
	#!/bin/bash
	# set this in a .env file with e.g.:
	# COC_KEY_COMMAND='pass path/to/luks/key'
	[ -z "${COC_KEY_COMMAND}" ] || {
		COCKEY=$(${COC_KEY_COMMAND})
		ansible coc -m shell -a "KEY='${COCKEY}' coc"
		exit $?
	}
	ansible coc -a coc

# backup justfiles
[group("actions")]
backup-justfiles:
	#!/bin/bash
	pbook="actions/justfilesbackup.yml"
	ansible-playbook "${pbook}" -l "${t}" && {
		ok "${t} justfiles saved in ~/repositories/justfiles"
	}

# remove cached facts and ansible outputs
[group("actions")]
reset:
	#!/usr/bin/env -S lua -llee
	require "lclib"
	caches = {
		eo("awk '/^fact_caching_connection/ {print $3}' $ANSIBLE_CONFIG"),
		lccache,
	}
	for _,cache in ipairs(caches) do
		x(f("rm -rvf %s/*", cache))
	end

_init:
	#!/bin/bash
	[ -e /tmp/ansible_facts/${t} ] && exit 0
	echo -ne "\e[2mgathering facts, please wait...\e[m"
	export ANSIBLE_STDOUT_CALLBACK=community.general.null
	ansible-playbook "actions/init.yml" -l "${t}"
	echo -ne "\r\e[K"

_completion:
	@just --summary

[private]
v:
	just --evaluate

t := "all"

LUA_PATH := env("LUA_PATH") + ";" + "scripts/?.lua"

set dotenv-load
set export
set shell := ["bash","-uc"]
# vim: ft=just
