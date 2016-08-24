#!/bin/sh

echo "Start gs:"

gnome-terminal -e "erl -s gs start_link -sname main -smp"

gnome-terminal -e "erl -noshell -s pc start_link pc1 -sname pc1 "

gnome-terminal -e "erl -noshell -s pc start_link pc2 -sname pc2"

gnome-terminal -e "erl -noshell -s pc start_link pc3 -sname pc3"

gnome-terminal -e "erl -noshell -s pc start_link pc4 -sname pc4"