#!/bin/bash

path=$(dirname $0)
cd "$path/../";
erl -make

curP=$(pwd)
mkdir -p "$curP/ebin/";
cd "$curP/ebin/";

erl -noshell -eval "watch:start(9999)."  -sname abc -mnesia '"../data/db"' -setcookie 123123resetcookie123123 -mnesia dump_log_write_threshold 50000 -mnesia dc_dump_limit 40  -env ERL_MAX_ETS_TABLES 20000  +P 10240000
