#!/bin/bash



path=$(dirname $0)
cd "$path/../src/";

erlc nqueue.erl && erl -noshell -eval "nqueue:start(9999)."
