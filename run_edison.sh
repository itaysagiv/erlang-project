#!/bin/sh

echo "Start gs:"

gnome-terminal -e "erl -s gs start_link -name main@192.168.1.102 -setcookie ok -smp"

#gnome-terminal -e "erl -noshell -s pc start_link pc1 -sname pc1 "

gnome-terminal -e "erl -noshell -s pc_edison start_link pc2 -name pc2@192.168.1.102 -setcookie ok"

gnome-terminal -e "erl -noshell -s pc_edison start_link pc3 -name pc3@192.168.1.102 -setcookie ok"

gnome-terminal -e "erl -noshell -s pc_edison start_link pc4 -name pc4@192.168.1.102 -setcookie ok"