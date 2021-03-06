#!/bin/bash

OUTPUTDIR_BASENAME="output"
TC_RED=
TC_YELLOW=
TC_GREEN=
TC_NULL=
TC_BLUE=
if test -t 1 -a -t 2; then
	TC_RED="\033[1;31m"
	TC_GREEN="\033[1;32m"
	TC_YELLOW="\033[1;33m"
	TC_BLUE="\033[1;34m"
	TC_NULL="\033[0m"
fi

function errcho()
{
	>&2 echo $*
}

function prepare()
{
	if test $# -lt 1; then
		errcho -e "Usage: $0 <gnuplot-script> [dep-file ...]"
		exit 1
	fi
	local src="$1"
	if test ! -f "$src"; then
		errcho -e "Source file not found: $src"
		exit 2
	fi
	shift
	for depfile in $*; do
		if test ! -f "$depfile"; then
			errcho -e "Dependency file not found: $depfile"
			exit 2
		fi
		# Absolute path?
		if [[ "${depfile:0:1}" == / || "${depfile:0:2}" == ~[/a-zA-Z] ]]; then
			continue
		fi
		local target_dir="${OUTPUTDIR_BASENAME}/$(dirname ${depfile#src/})"
		mkdir -p "$target_dir"
		test -h "$target_dir/$(basename $depfile)" || ln -sf $(realpath $depfile) "$target_dir"
	done
	echo "$src"
}

function find_output()
{
	local src="$1"
	local output_line=$(grep -iE "\s*set\s+output\s+" "$src" 2>/dev/null | tail -1 2>/dev/null)
	local output=""
	if test -z "$output_line"; then
		output="${src%.*}.pdf"
		errcho -e "${TC_YELLOW}Warning: \"set output\" command not found in script \"$src\", I will try to crop \"$output\" later.${TC_NULL}"
		echo "$output"
		return 1
	fi
	output=$(sed 's/^\s*set\s\+output\s\+//' <<< "$output_line")
	[[ "$output" == \"*\" || "$output" == \'*\' ]] && output=${output:1:-1}
	echo "$output"
	return 0
}

function execute_or_fail()
{
	local mayfail=$1
	shift
	local log_file=$(mktemp .log.XXXX)
	if test $mayfail -eq 0; then
		echo -e "\n${TC_BLUE}Executing: $* ${TC_NULL}"
	else
		echo -e "\n${TC_BLUE}Try executing: $* ${TC_NULL}"
	fi

	$* &>$log_file
	local _errno=$?
	if test $_errno -eq 0; then
		echo -e "${TC_GREEN}Command success: $*${TC_NULL}"
		rm -f $log_file
		return 0
	fi
	>&2 cat $log_file
	rm -f $log_file
	errcho -e "($_errno) ${TC_RED}Failed to execute: $* ${TC_NULL}"

	if test $mayfail -eq 0; then
		exit $_errno
	else
		return $?
	fi
}

function do_draw()
{
	local src="$1"
	local abs_src="$(realpath "$1")"
	local mayfail=$3
	local target_dir=${OUTPUTDIR_BASENAME}/$(dirname ${src#src/})
	test -d "$target_dir" || mkdir -p "$target_dir"
	cd "$target_dir"
	execute_or_fail 0 gnuplot "$abs_src" < /dev/null
	local suffix="${2##*.}"
	if [[ "$suffix" == "pdf" ]]; then
		execute_or_fail $mayfail pdfcrop "$2"
		execute_or_fail $mayfail mv "${2%.pdf}-crop.pdf" "$2"
	elif [[ "$suffix" == "png" ]]; then
		# Do nothing
		:
	else
		errcho -e "${TC_YELLOW}Warning: unknown type \"$suffix\" of output file \"$2\".${TC_NULL}"
	fi
}

function main()
{
	local src
	src=$(prepare $*)
	local _errno=$?
	test $_errno -ne 0 && exit $_errno

	local output
	output=$(find_output "$src")
	do_draw "$src" "$output" $?
}

main $*
