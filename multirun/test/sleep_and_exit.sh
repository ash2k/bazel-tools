#!/usr/bin/env bash

echo "sleeping before exiting $1"
sleep "$1"
echo "exiting: $2"
exit "$2"
