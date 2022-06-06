#!/bin/bash

cd $(dirname $(realpath $0))
exec 2>&1 > Makefile

DRAW_SCRIPT=core/draw.sh

# Do not use these in stdout! stdout is redirected to Makefile
TC_RED=
TC_YELLOW=
TC_GREEN=
TC_NULL=
TC_BLUE=
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
		output="${src%.*}.pdf"
		errcho -e "${TC_RED}Error: \"set output\" command not found in script \"$src\".${TC_NULL}"
		echo "$output"
		exit 1
	fi
	output=$(sed 's/^\s*set\s\+output\s\+//' <<< "$output_line")
	[[ "$output" == \"*\" || "$output" == \'*\' ]] && output=${output:1:-1}
	if [[ "$output" == *" "* ]]; then
		errcho -e "${TC_RED}Error: output name \"$output\" contains space.${TC_NULL}"
		exit 2
	fi
	echo "$output"
	return 0
}

declare -A targets

for f in src/*; do
	t=$(find_output "$f")
	_errno=$?
	test $_errno -eq 0 || exit $_errno
	targets["$t"]="$f"
done

errcho "Generating Makefile ..."
errcho "Adding targets ..."
echo -n "RAW_TARGETS := "
for t in ${!targets[@]}; do
	echo -n "$t "
done
echo ""
echo -n "TARGETS := "
for t in ${!targets[@]}; do
	echo -n "output/$t "
done
echo ""

errcho "Adding rules for all ..."
cat << EOF

.PHONY: all \$(RAW_TARGETS)
all: \$(TARGETS)

EOF

for t in ${!targets[@]}; do
	src=${targets[$t]}
	errcho "Adding rules for ${src} ..."
	cat << EOF
${t}: output/${t}

output/${t}: ${DRAW_SCRIPT} ${src}
	@echo -e "\t${t}"
	@sh \$^ >/dev/null

EOF
done

errcho "Adding rules for clean ..."
cat << EOF
.PHONY: clean
clean:
	-rm -f \$(TARGETS)
EOF

errcho "Done."
