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
cnames: 
	#!/usr/bin/env -S lua -llee
	cmd = "ansible-inventory --list --limit '{{t}}'"
	data = json.decode(ea(cmd))
	for host,keys in pairs(data._meta.hostvars) do
		chost = host
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
	@lua ./scripts/status.lua

# show info 
[group("reporting")]
info:
	#!/usr/bin/env -S lua -llee
	require "lclib"
	local ocache = pblua("vigilax.yml")
	hosts = ocache.plays[1].tasks[1].hosts
	lines = { "Host,uproc,Distribution,Updates,Uptime,Avg" }
	for host,data in pairs(hosts) do
		info = json.decode(data.stdout)
		table.insert(lines, f([["%s","%s","%s","%s,%s,%s"]],
			host, info.nproc,info.distro, info.updates,
			info.uptime, info.loadavg))
	end
	x(f([[echo "%s" | xan view -pIM]], table.concat(lines, "\n")))

# update packages
[group("actions")]
machinesupdate:
	@ansible-playbook -v "actions/machinesupdate.yml" -l "${t}"

# reboot
[group("actions")]
reboot:
	@ansible "${t}" -bm reboot

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
connect-user host:
	#!/usr/bin/env -S lua -llee
	host = "{{host}}"
	data = json.decode(ea("ansible-inventory --host "..host))
	remote = data.ansible_incus_remote
	if remote then
		x(f("incus exec %s:%s -- su - unix", remote, host))
	else
		x("ssh "..host)
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

# backup justfiles, .aqui and .env
[group("actions")]
justfiles-backup:
	@lua scripts/justfilesbackup.lua

# remove cached facts and ansible outputs
[group("actions")]
reset:
	rm -rvf /tmp/ansible_facts/* /dev/shm/lc/*

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
