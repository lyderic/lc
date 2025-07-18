alias h   := _help
alias ls  := names
alias s   := status
alias cn  := cnames
alias gr  := groups
alias u   := connect-user
alias rs  := reset
alias b   := backup-justfiles
alias ua  := machinesupdate
alias cz  := chezmoiupdate
alias reb := reboot
alias one := oneline

_help:
	@just --list --unsorted --alias-style left --color always \
		--list-heading='' --list-prefix=' ' \
		| sed -e 's/alias: //'

# list names
[group("listing")]
names:
	@ansible "${t}" --list | sed 1d | awk '{print $1}' | sort | less -FRIX

# list names with remotes
[group("listing")]
cnames:
	#!/usr/bin/env -S lua -llee
	x([[lc _init "${t}"]])
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
[group("listing")]
groups:
	#!/bin/bash
	[ "${t}" == "all" ] && {
		ansible-inventory --list | jq 'keys' | \
			sed '/_meta/d' | tr -d '"' | yq -P
		exit 0
	}
	ansible-inventory "${t}" --graph | less -FRIX

# ping pong
[group("reporting")]
ping:
	@ansible-playbook "actions/ping.yml" \
		-l "${t}"

# status vigilax reporting
[group("reporting")]
status:
	@./scripts/status.lua -t "${t}"

# update packages
[group("actions")]
machinesupdate:
	ansible-playbook -v actions/machinesupdate.yml -l "${t}"

# reboot
[group("actions")]
reboot:
	ansible "${t}" -bom reboot

# update chezmoi
[group("actions")]
chezmoiupdate:
	#!/bin/bash
	ansible "${t}" -a 'chezmoi update'
	ansible "${t}" -ba 'chezmoi update'

# one line output of <cmd>
[group("actions")]
oneline *cmd:
	#!/usr/bin/env -S lua -llee
	expression = "^(%S+) %| %S+ %| %S+=%d+ %| %(%S+%) (.+)$"
	for line in e("ansible {{t}} -om shell -a '{{cmd}}'"):lines() do
		if line:find("FAILED!") then
			host = line:match("^(%S+)")
			printf("\27[1m%-9.9s\27[m \27[31mERROR\27[m\n", host)
		else
			host, output = line:match(expression)
			printf("\27[1m%-9.9s\27[m %s\n", host, output)
		end
	end

# connect as uid 1000
[group("actions")]
connect-user host:
	#!/usr/bin/env -S lua -llee
	x("lc _init {{host}}")
	fh = io.open("/tmp/ansible_facts/{{host}}")
	if not fh then print("invalid host!") io.exit(1) end
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

# remove cached facts
[group("actions")]
reset:
	rm -rvf /tmp/ansible_facts/*

_init target="all":
	#!/bin/bash
	[ -e /tmp/ansible_facts/{{target}} ] && exit 0
	echo -ne "\e[2mgathering facts, please wait...\e[m"
	export ANSIBLE_STDOUT_CALLBACK=community.general.null
	ansible-playbook "actions/init.yml" -l {{target}}
	echo -ne "\r\e[K"

[private]
v:
	just --evaluate
	echo "target=${t}"

t := "all"

set dotenv-load
set export
set shell := ["bash","-uc"]
# vim: ft=just
