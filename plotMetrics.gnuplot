# Gnuplot

set datafile separator ';'

#set xdata time                  # tells gnuplot the x axis is time data
#set timefmt "%Y-%m-%dT%H:%M:%S" # specify our time string format
#set format x "%H:%M:%S"         # otherwise it will show only MM:SS

set key autotitle columnhead     # use the first line as title
set ylabel "[bps]"               # label for the Y axis
set xlabel 'Time'                # label for the X axis
set y2tics                       # enable second axis
set ytics nomirror               # dont show the tics on that side
set y2label "Second Y Axis"      # label for second axis

plot [] [-100000:1.5e6] "../experiments/automated/cable/ue_m_20-04-09_16:56:08.csv" using 1:8 with lines, '' using 1:13 with lines, '' using 1:5 with lines axis x1y2