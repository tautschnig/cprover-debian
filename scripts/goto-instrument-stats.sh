#!/bin/bash

# echo "Total packages to dump: `ls build/*/goto-binaries.tar.bz2 | wc -l`"
echo "Packages successfully dumped: `ls dump-logs/*-succeeded | wc -l`"
echo "Packages failing to dump: `ls dump-logs/*-failed | wc -l`"
echo

failed_dump=0
failed_comp=0
failed_conv=0

failed_dump=`ls dump/*/failed-binaries/* | grep -v '\*$' | wc -l`
failed_comp=`ls dump/*/failed-recompile/* | grep -v '\.c$' | grep -v '\*$' | wc -l`
failed_conv=`ls dump/*/failed-converge/* | grep -v '\*$' | wc -l`

echo "Failed dump: $failed_dump"
echo "Failed compile: $failed_comp"
echo "Failed converge: $failed_conv"

