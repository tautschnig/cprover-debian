#!/bin/bash

if [ -z "$1" ] ; then
  N=100
else
  N=$1
fi

for l in logs/failed-* ; do
  p=`echo $l | sed 's#^logs/failed-##'`
  if grep -q "^- $p:" notes ; then
    continue
  fi

  tail -n $N $l > $l.tail
  if grep -q "main symbol \`c::main' not in context$" $l.tail ; then
    echo "- $p: main not in context" >> notes
  elif egrep -q "error: conflicting definition for (variable|symbol)" $l.tail ; then
    t1="`grep -A4 "error: conflicting definition for (variable|symbol)" $l.tail | sed -n '2p' | cut -f2- -d:`"
    t2="`grep -A4 "error: conflicting definition for (variable|symbol)" $l.tail | sed -n '4p' | cut -f2- -d:`"
    if [ "$t1" = "$t2" ] ; then
      echo "- $p: conflicting types with same type" >> notes
      rm -rf build/$p
    else
      echo "- $p: conflicting types $t1 vs. $t2" >> notes
    fi
  elif grep -q "symbol \`.*' defined twice with different types" $l.tail ; then
    t1="`grep -A2 "symbol \\\`.*' defined twice with different types" $l.tail | sed -n '2p' | cut -f2- -d:`"
    t2="`grep -A2 "symbol \\\`.*' defined twice with different types" $l.tail | sed -n '3p' | cut -f2- -d:`"
    if [ "$t1" = "$t2" ] ; then
      echo "- $p: conflicting types with same type" >> notes
      rm -rf build/$p
    else
      echo "- $p: conflicting types $t1 vs. $t2" >> notes
    fi
  elif grep -q "syntax error before \`struct'$" $l.tail ; then
    echo "- $p: register struct in KnR" >> notes
    rm -rf build/$p
  elif grep -q "syntax error before \`const'$" $l.tail ; then
    echo "- $p: register const in KnR" >> notes
    rm -rf build/$p
  ## elif grep -q "^dpkg-checkbuilddeps: Unmet build dependencies:.*gnome-pkg-tools" $l.tail ; then
  ##   echo "- $p: gnome-pkg-tools" >> notes
  ##   rm -rf build/$p
  elif grep -q "^error: duplicate definition of function" $l.tail ; then
    echo "- $p: duplicate definition of function" >> notes
  elif grep -q "failed to zero-initialize \`struct " $l.tail ; then
    echo "- $p: failed to zero init struct" >> notes
    rm -rf build/$p
  elif grep -q ": implicit conversion not permitted$" $l.tail ; then
    echo "- $p: `grep ": implicit conversion not permitted$" $l.tail`" >> notes
  elif grep -q "^identifier c::tag-.*\$link.* not found$" $l.tail ; then
    echo "- $p: linking-specific identifier not found" >> notes
  else
    echo "Cannot classify $l"
  fi
  rm $l.tail
done

