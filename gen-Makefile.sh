#!/bin/bash

cd $(dirname $(realpath $0))
exec 2>&1 > Makefile
shopt -s lastpipe

DRAW_SCRIPT=core/draw.sh

# Do not use these in stdout! stdout is redirected to Makefile
TC_RED=
TC_YELLOW=
TC_GREEN=
TC_BLUE=
TC_NULL=
if test -t 2; then
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

function find_output()
{
	local src="$1"
	local output_line=$(grep -iE "\s*set\s+output\s+" "$src" 2>/dev/null | tail -1 2>/dev/null)
	local output=""
	if test -z "$output_line"; then
		local subdir_path="${src#src/}"
		output="${subdir_path%.*}.pdf"
		#errcho -e "${TC_RED}  Fatal: \"set output\" command not found in script \"$src\".${TC_NULL}"
		echo "$output"
		exit 1
	fi
	output=$(sed 's/^\s*set\s\+output\s\+//' <<< "$output_line")
	[[ "$output" == \"*\" || "$output" == \'*\' ]] && output=${output:1:-1}
	if [[ "$output" == *" "* ]]; then
		#errcho -e "${TC_RED}  Fatal: output name \"$output\" contains space.${TC_NULL}"
		exit 2
	fi
	echo "$output"
	return 0
}

function find_input_output()
{
	local src="$1"
	input_files=""
	local input_file
	grep -iE "^\s*#\s*input:\s+" "$src" 2>/dev/null |\
	while read line; do
		input_file="$(sed 's/^\s*\#\s*input:\s\+//' <<< "$line")"
		[[ "$input_file" == \"*\" || "$input_file" == \'*\' ]] && input_file=${input_file:1:-1}

		# Absolute path or relative path?
		if [[ "${input_file:0:1}" == / || "${input_file:0:2}" == ~[/a-zA-Z] ]]; then
			input_files+=" ${input_file}"
		else
			input_files+=" $(dirname $src)/${input_file}"
		fi
	done
	local output_line=$(grep -iE "^\s*#\s*output:\s+" "$src" 2>/dev/null | tail -1)
	local output_file=""
	if test -z "$output_line"; then
		output_file=$(find_output $src)
		if test $? -ne 0; then
			local subdir_path="${src#src/}"
			output_file="${subdir_path%.*}.pdf"
			errcho -e "${TC_RED}Warning: no output files valid found in script ${TC_BLUE}\"$src\"${TC_RED}, using ${TC_YELLOW}\"$output_file\"${TC_RED} instead.${TC_NULL}"
		else
			[[ "$output_file" == \"*\" || "$output_file" == \'*\' ]] && output_file=${output_file:1:-1}
			errcho -e "${TC_RED}Warning: no output files defined in script ${TC_BLUE}\"$src\"${TC_RED}, using ${TC_YELLOW}\"$output_file\"${TC_RED} in \"set output\" command. This might be incorrect if variable used in path.${TC_NULL}"
		fi
		echo "$output_file" "$input_files"
		return 0
	fi
	output_file=$(sed 's/^\s*\#\s*output:\s\+//' <<< "$output_line")
	[[ "$output_file" == \"*\" || "$output_file" == \'*\' ]] && output_file=${output_file:1:-1}
	if [[ "$output_file" == *" "* ]]; then
		errcho -e "${TC_RED}Error: output name \"$output_file\" contains space.${TC_NULL}"
		return 2
	fi

	echo "$output_file" "$input_files"
	return 0
}

declare -A src_map
declare -A deps

find src/ -name *.gnu -type f |\
while read f; do
	in_out=$(find_input_output "$f")
	_errno=$?
	test $_errno -eq 0 || exit $_errno

	read t i <<< "$in_out"
	src_map["$t"]="$f"
	deps["$t"]="$f $i"
done

errcho "Generating Makefile ..."
errcho "Adding deps ..."
echo -n "RAW_TARGETS := "
for t in ${!deps[@]}; do
	echo -n "$t "
done
echo ""
echo -n "TARGETS := "
for t in ${!deps[@]}; do
	echo -n "output/$t "
done
echo ""

errcho "Adding rules for all ..."
cat << EOF

.PHONY: all \$(RAW_TARGETS)
all: \$(TARGETS)

EOF

for t in ${!deps[@]}; do
	src=${deps[$t]}
	errcho "Adding rules for ${src_map[$t]} ..."
	cat << EOF
${t}: output/${t}

output/${t}: ${DRAW_SCRIPT} ${src}
	@mkdir -p $(dirname output/${t})
	@echo -e "\t${t}"
	@sh \$< \$(word 2,\$^) >/dev/null

EOF
done

errcho "Adding rules for clean ..."
cat << EOF
.PHONY: clean
clean:
	-rm -f \$(TARGETS)
EOF

errcho "Done."
