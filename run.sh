#!/bin/sh

echo "Start gs:"

erl -noshell -s gs start_link -s init stop -smp
