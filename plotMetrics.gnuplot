# Gnuplot

FACTOR=1e6  # Para mostrar la tasa de datos en Mbps
# Variable TITLE pasada como argumento
# Variable TIME pasada como argumento
ENB_METRICS=sprintf("../experiments/automated/cable/enb_m_%s.csv",TIME)
UE_METRICS=sprintf("../experiments/automated/cable/ue_m_%s.csv",TIME)
AVERAGES=sprintf("../experiments/automated/cable/averages_%s.csv",TIME)

max(x, y) = (x > y ? x : y)
round(x) = x - floor(x) < 0.5 ? floor(x) : ceil(x)
round2(x, n) = round(x*10**n)*10.0**(-n)

set datafile separator ';'

stats ENB_METRICS using 4:5 nooutput
MAX_ENB_DL=STATS_max_x
MAX_ENB_UL=STATS_max_y
stats UE_METRICS using 9:14 nooutput
MAX_UE_DL=STATS_max_x
MAX_UE_UL=STATS_max_y
MAX_R=max(max(MAX_ENB_UL,MAX_ENB_DL),max(MAX_UE_UL,MAX_UE_DL))
MAX_Y=round2((MAX_R/FACTOR)*1.1,1)
MIN_Y=-round2((MAX_R/FACTOR)*0.1,1)

set style data lines

#set xdata time                  # tells gnuplot the x axis is time data
#set timefmt "%H:%M:%S"          # specify our time string format
#set format x "%H:%M:%S"         # otherwise it will show only MM:SS

set multiplot layout 2,1 title TITLE

set ylabel "R_b [Mbps]"
set xrange [30:130]
set ytics nomirror               # dont show the tics on that side
set yrange [0:MAX_Y]

set key autotitle columnhead center bottom outside horizontal

set y2tics nomirror # enable second axis
set y2range [0:6]
set y2label "# UEs"
set title "eNB"
plot ENB_METRICS using 2:($4/FACTOR) lc 6,\
'' using 2:($5/FACTOR) lc 7,\
'' using 2:3 lc 1 axis x1y2,\
AVERAGES using 1:($2/FACTOR) with points ls 6 lc 6,\
'' using 1:($3/FACTOR) lc 6 lw 3,\
'' using 1:($4/FACTOR) lc 7 lw 3 dt 3,\
'' using 1:($5/FACTOR) with points ls 6 lc 7,\
'' using 1:($6/FACTOR) lc 6 lw 3 dt 3,\
'' using 1:($7/FACTOR) lc 7 lw 3

set y2tics nomirror
set y2range [0:35]
set y2label "Quality"
set title "UE"
set xlabel 'Time [s]'
plot UE_METRICS using 2:($9/FACTOR) lc 6,\
'' using 2:($14/FACTOR) lc 7,\
'' using 2:6 with lines lc 1 axis x1y2,\
'' using 2:12 with lines lc 4 axis x1y2,\
AVERAGES using 9:($10/FACTOR) with points ls 6 lc 6,\
'' using 9:($11/FACTOR) lc 6 lw 3,\
'' using 9:($12/FACTOR) lc 7 lw 3 dt 3,\
'' using 9:($13/FACTOR) with points ls 6 lc 7,\
'' using 9:($14/FACTOR) lc 6 lw 3 dt 3,\
'' using 9:($15/FACTOR) lc 7 lw 3
# '' using 9:($15/FACTOR) notitle lc 7 lw 3

unset multiplot