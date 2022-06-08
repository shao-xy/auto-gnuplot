# input:
# output: demo/sampling.1.png

set terminal pngcairo  transparent enhanced font "arial,10" fontscale 1.0 size 600, 400 
set output 'demo/sampling.1.png'
set key fixed right top vertical Right noreverse enhanced autotitle box lt black linewidth 1.000 dashtype solid
set key opaque
set style data lines
set trange [ 20.0000 : 50.0000 ] noreverse nowriteback
set urange [ 1.00000 : 100.000 ] noreverse nowriteback
set vrange [ 1.00000 : 100.000 ] noreverse nowriteback
set xrange [ 1.00000 : 100.000 ] noreverse nowriteback
set x2range [ * : * ] noreverse writeback
set yrange [ * : * ] noreverse writeback
set y2range [ * : * ] noreverse writeback
set zrange [ * : * ] noreverse writeback
set cbrange [ * : * ] noreverse writeback
set rrange [ * : * ] noreverse writeback
NO_ANIMATION = 1
## Last datafile plotted: "+"
plot '+' using 1:(10. + sin($1)) title "trange [20:50]"
