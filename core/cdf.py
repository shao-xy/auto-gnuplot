#!/usr/bin/env python3

import sys
import os
import argparse
import subprocess
import threading

#TEMP_DIR = './.draw_cdf'

isatty = sys.stdout.isatty()
COLOR_DECORATOR_RED = isatty and '\033[1;31m' or ''
COLOR_DECORATOR_GREEN = isatty and '\033[1;32m' or ''
COLOR_DECORATOR_YELLOW = isatty and '\033[1;33m' or ''
COLOR_DECORATOR_BLUE = isatty and '\033[1;34m' or ''
COLOR_DECORATOR_PURPLE = isatty and '\033[1;35m' or ''
COLOR_DECORATOR_CLEAR = isatty and '\033[0m' or ''

def parse_args():
	parser = argparse.ArgumentParser()
	parser.add_argument('script_name', help='Full path figure name with NO SUFFIX like ".pdf". This option decides the path of the script and the output figure.')
	parser.add_argument('input_data', nargs='+', help='Source input data file.')
	parser.add_argument('-k', '--column', type=int, default=1, help='The target column to draw.')
	parser.add_argument('-m', '--show-meta', action='store_true', help='Show metadata in the figure (P99, avg, etc.)')
	parser.add_argument('-t', '--title', help='Title of the CDF graph')
	parser.add_argument('-x', '--xlabel', help='Label for X axis')
	parser.add_argument('-u', '--upper-legend', action='store_true', help='Move the legends to top outside instead of bottom right.')
	parser.add_argument('-l', '--logx', help='Set x axis to logscale', action='store_true')
	parser.add_argument('-p', '--numpat', help='Pattern to print number into gnuplot script. E.g. %%d')
	return parser.parse_args()

def show_text(text, tag='MAIN'):
	assert(isinstance(text, str) and isinstance(tag, str))
	for line in text.split('\n'):
		print(f'{COLOR_DECORATOR_GREEN}[{tag}]{COLOR_DECORATOR_CLEAR} {line}')

def show_prompt(prompt, tag='MAIN'):
	assert(isinstance(prompt, str) and isinstance(tag, str))
	print(f'{COLOR_DECORATOR_GREEN}[{tag}]{COLOR_DECORATOR_YELLOW} {prompt}{COLOR_DECORATOR_CLEAR}')

def show_error(prompt):
	assert(isinstance(prompt, str))
	print(f'{COLOR_DECORATOR_RED}[ERROR]{COLOR_DECORATOR_PURPLE} {prompt}{COLOR_DECORATOR_CLEAR}')

def tostring(number, args):
	return args.numpat and (args.numpat % number) or str(number)

def call_shell(cmd):
	if not cmd:	return None, None
	return subprocess.Popen(cmd, shell=True,\
			stdout=subprocess.PIPE, stderr=subprocess.PIPE)\
			.communicate()

class HandledData(object):
	def __init__(self, name, path, sorted_path, medium_value,\
				 average, avg_ln, total_lines, p99_value):
		self.name = name
		self.path = path
		self.sorted_path = sorted_path 
		self.medium_value = medium_value 
		self.average = average 
		self.avg_ln = avg_ln 
		self.total_lines = total_lines 
		self.p99_value = p99_value 

	def gen_labels(self, args, next_label = 1):
		return """set label %d "Medium" at %s,0.5 point pointtype 7 pointsize 1.5
set label %d "Avg" at %s,%.2f point pointtype 7 pointsize 1.5
set label %d "P99" at %s,0.99 point pointtype 7 pointsize 1.5
"""\
		% ( next_label, tostring(self.medium_value, args),\
			next_label + 1, tostring(self.average, args), float(self.avg_ln) / self.total_lines,\
			next_label + 2, tostring(self.p99_value, args) ), next_label + 3

	def gen_plot(self, column, next_lt = 1):
		return '"%s" using (($%d)):(1./%d.) with linespoints title \'%s\' lw 2 lt %d smooth cumulative'\
		% (os.path.basename(self.sorted_path), column, self.total_lines, self.name.replace('_', '\\_'), next_lt), next_lt + 1

def handle_single_file(src, collector, args):
	src_bn = os.path.basename(src)
	script_dir_path = os.path.dirname(args.script_name)
	sorted_path = os.path.join(script_dir_path, 'sorted_' + src_bn)

	# Get name
	dot_rindex = src_bn.rfind('.')
	src_name = dot_rindex < 0 and src_bn or src_bn[:dot_rindex]

	# Tag
	tag = src_name

	# Sort
	show_prompt(f'Sorting {src}')
	call_shell(f'sort -nk {args.column} "{src}" -o "{sorted_path}"')

	if not args.show_meta:
		show_prompt('Counting lines ...', tag);
		out, err = call_shell(f'wc -l {sorted_path}')
		if err:
			show_error(err)
			return 0
		total_lines = int(out.strip().split()[0])
		collector.append(HandledData(src_name, src, sorted_path, 0,\
									 0, 0, total_lines, 0))
	else:
		show_prompt('Counting lines and calculating average ...', tag);
		out, err = call_shell('awk \'{sum+=$1} END {print NR; print sum/NR}\' %s' % sorted_path)
		if err:
			show_error(err)
			return 0
		filedata = out.split()
		total_lines = int(filedata[0])
		average = float(filedata[1])
		show_prompt('Searching for medium value, P99 value and line number of average', tag)
		medium_ln = total_lines / 2
		avg_ln = -1
		p99_ln = int(0.99 * float(total_lines))
		fin = open(sorted_path, 'r')
		line_count = 0
		while True:
			# Read line
			line = fin.readline()
			if not line:	break
			line_count += 1
			line = line.strip()

			try:
				line = line.split()[args.column - 1]
			except IndexError:
				show_error(f'Line {line_count}: no column {args.column}. Whole line: {line}')

			# Parse string to number
			try:
				line_dat = int(line)
			except ValueError:
				try:
					line_dat = float(line)
				except ValueError:
					show_error('Line %d: Illegal string %s' % (line_count, line))
					return

			# Check medium
			if line_count == medium_ln:
				medium_value = line_dat

			# Check average
			if avg_ln < 0 and line_dat >= average:
				avg_ln = line_count

			# Check P99
			if line_count == p99_ln:
				p99_value = line_dat
				break # We assume this is the last line we concern
		fin.close()
		show_text('Total lines: %d\nAverage: %s\nMedium: %s\nP99: %s'\
				% (total_lines, tostring(average, args),\
				tostring(medium_value, args), tostring(p99_value, args)), tag)

		collector.append(HandledData(src_name, src, sorted_path, medium_value,\
									 average, avg_ln, total_lines, p99_value))

def main():
	args = parse_args()

	show_prompt('Handling the original file(s) ...');

	collector = []
	thread_pool = []
	for single_src in args.input_data:
		t = threading.Thread(target=handle_single_file,\
							args=(single_src, collector, args))
		t.start()
		thread_pool.append(t)

	for t in thread_pool:
		t.join()
	
	try:
		assert len(collector) > 0
	except AssertionError:
		sys.exit(-1)

	# Generate GNUPLOT script
	show_prompt("Generating script ...")
	script_dir_path = os.path.dirname(args.script_name)
	script_basename = os.path.basename(args.script_name)
	script_path = os.path.join(script_dir_path, script_basename + '.gnu')
	output_path = script_basename + '.pdf'
	gp_fout = open(script_path, 'w')
	if not gp_fout:
		print(f'Could not write scripts to file {script_path}.')
		return -1

	for data_item in collector:
		sorted_bn = os.path.basename(data_item.sorted_path)
		gp_fout.write(f'# input: {sorted_bn}\n')

	key_command = args.upper_legend and 'top center horizontal outside' or 'bottom right'
	script_templ = f"""# output: {output_path}

set terminal pdfcairo lw 2 font "Times New Roman,26" size 4,3
set output "{output_path}"
set ylabel "CDF"
set yrange [0:1]
set ytics 0.2
set key box {key_command}
set style rect fc lt -1 fs solid 0.15 noborder
set grid"""
	
	gp_fout.write('%s\n' % script_templ)
	args.title and gp_fout.write('set title \"%s\"\n' % args.title)
	args.logx and gp_fout.write('set logscale x\n')
	args.xlabel and gp_fout.write('set xlabel \"%s\"\n' % args.xlabel)

	if args.show_meta:
		next_label = 1
		for data_item in collector:
			script_cmd, next_label = data_item.gen_labels(args, next_label)
			gp_fout.write(script_cmd)

	gp_fout.write('plot %s' % collector[0].gen_plot(args.column)[0])
	collector = collector[1:]
	next_lt = 2
	for data_item in collector:
		script_cmd, next_lt = data_item.gen_plot(args.column, next_lt)
		gp_fout.write(',\\\n\t%s' % script_cmd)
	
	gp_fout.write('\n')
	gp_fout.close()

	show_prompt(f'Gnuplot script written to {script_path}')

	return 0

if __name__ == '__main__':
	sys.exit(main())

