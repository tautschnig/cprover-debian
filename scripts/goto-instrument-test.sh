#!/bin/bash

set -e
ulimit -S -v 16000000

BASEDIR=$PWD
LOGDIR=$PWD/dump-logs
DUMPDIR=$PWD/dump

mkdir -p $LOGDIR $DUMPDIR

dump_package() {
  pkg=$1
  logf=$2
    
  echo "$(date +%F\ %T) Dumping $pkg"
  echo "$(date +%F\ %T) Dumping $pkg" > $logf
  ec=0

  while [ $((`df $BASEDIR | tail -1 | awk '{ print $4 }'`/1024)) -lt 2000 ] ; do
    echo "Waiting for disk space to become available before unpacking $pkg"
    sleep 30
  done

  mkdir -p $DUMPDIR/$pkg
  cd $DUMPDIR/$pkg
  tar xjf $BASEDIR/build/$pkg/goto-binaries.tar.bz2
do_recompile=1
ifs="$IFS"
IFS="
"
  find goto-binaries -type f > goto-binaries.list
  while read f ; do
    if echo "$f" | grep -q '\.linked$' ; then
      continue
    fi
    while [ $((`df $BASEDIR | tail -1 | awk '{ print $4 }'`/1024)) -lt 20 ] ; do
      echo "Waiting for disk space to become available before dumping $f"
      sleep 30
    done
    ff="`basename "$f"`"
    echo -n "$(date +%F\ %T) " >> $logf
    if ! $HOME/goto-instrument --dump-c "$f" "$ff.c" >> $logf 2>&1 ; then
      mkdir -p $DUMPDIR/$pkg/failed-binaries/
      cp "$f" $DUMPDIR/$pkg/failed-binaries/
      ec=1
    elif [ $do_recompile -eq 1 ] ; then
      # bug: statement expressions being lost
      perl -p -i -e 's/[#\$\w]+#array_size\d+/42/g' "$ff.c"
      
      for i in 1 2 3 4 5 6 7 ; do
        # make sure there is no "irep" generated anywhere
        if grep -wq 'irep' "$ff.c" ; then
          sed -i 's/irep/#irep/' "$ff.c"
        fi
        
        if ! $HOME/wheezy-base.cow/usr/bin/goto-cc -c "$ff.c" >> $logf 2>&1 ; then
          mkdir -p $DUMPDIR/$pkg/failed-recompile/
          cp "$f" $DUMPDIR/$pkg/failed-recompile/
          cp "$ff.c" $DUMPDIR/$pkg/failed-recompile/
          ec=1
          break
        else
          echo -n "$i: " >> $logf
          if ! $HOME/goto-instrument --dump-c "$ff.o" "$ff.c" >> $logf 2>&1 ; then
            ec=1
            break
          fi
          cp "$ff.c" "$ff.$i.c"
          ib=$((i - 1))
          if [ $i -gt 1 ] ; then
            if diff "$ff.$ib.c" "$ff.$i.c" > /dev/null ; then
              echo "Convergence at step $ib" >> $logf
              break
            elif [ $i -eq 7 ] ; then
              echo "No convergence after $i iterations" >> $logf
              mkdir -p $DUMPDIR/$pkg/failed-converge/
              diff -u "$ff.$ib.c" "$ff.$i.c" > "$DUMPDIR/$pkg/failed-converge/$ff.diff" || true
              cp "$ff.$ib.c" $DUMPDIR/$pkg/failed-converge/
              ec=1
            fi
          fi
        fi
      done
      rm -f "$ff.c" "$ff.o" "$ff.1.c" "$ff.2.c" "$ff.3.c" "$ff.4.c" "$ff.5.c" "$ff.6.c" "$ff.7.c"
    fi
  done < goto-binaries.list
  IFS="$ifs"
  rm -r goto-binaries goto-binaries.list
  cd $BASEDIR
  rmdir --ignore-fail-on-non-empty $DUMPDIR/$pkg
  if [ $ec -eq 0 ] ; then
    mv $logf $LOGDIR/dump-$pkg-succeeded
  else
    mv $logf $LOGDIR/dump-$pkg-failed
  fi
}

for d in build/* ; do
  package=`basename $d`
  ln -s $package $LOGDIR/.$package.dump-lock 2> /dev/null || continue
  if [ -f $d/goto-binaries.tar.bz2 ] && \
    [ ! -e $LOGDIR/dump-$package-succeeded ] && \
    [ ! -e $LOGDIR/dump-$package-failed ] ; then
    dump_package $package `readlink -f $LOGDIR/.$package.dump-log`
  fi
  rm -f $LOGDIR/.$package.dump-lock
done

