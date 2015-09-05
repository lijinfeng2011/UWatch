#!/bin/bash



path=$(dirname $0)
cd "$path/../src/";

erlc *.erl && erl -noshell -eval "watch:start(9999)."
