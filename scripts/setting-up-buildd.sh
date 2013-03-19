#!/bin/bash
#
# Copyright (c) 2012 Michael Tautschnig <michael.tautschnig@cs.ox.ac.uk>
# Department of Computer Science, University of Oxford
# 
# All rights reserved. Redistribution and use in source and binary forms, with
# or without modification, are permitted provided that the following
# conditions are met:
# 
#   1. Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
# 
#   2. Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
# 
#   3. Neither the name of the University nor the names of its contributors
#      may be used to endorse or promote products derived from this software
#      without specific prior written permission.
# 
#    
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS `AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

set -evx

# requires proper sudoers setup:
#Cmnd_Alias  COWBUILDER=/usr/sbin/cowbuilder
#mictau  ALL=NOPASSWD:  COWBUILDER
#Defaults!COWBUILDER  setenv

#cow_base=/var/cache/pbuilder/wheezy-base-mt.cow
cow_base=$HOME/wheezy-base.cow
if [ -d $cow_base ] ; then
  echo " \
umount /dev/pts ; \
umount /var/cache/pbuilder/ccache ; \
umount /proc ; \
chown -R $UID . ; \
exit" | sudo cowbuilder --login --save-after-login --basepath $cow_base
fi
rm -rf $cow_base

cat > $HOME/.pbuilderrc.tmp <<"EOF"
EXTRAPACKAGES="eatmydata"

use_eatmydata=1
if [ -s debian/changelog ] ; then
  cur_pkg=$(dpkg-parsechangelog|sed -n 's/^Source: //p')
  for p in acl2 archivemail bibletime clojure1.2 dico dulwich eglibc libaudio-mpd-perl libdbd-firebird-perl libfile-sync-perl libio-async-loop-glib-perl libio-socket-ip-perl libslf4j-java maxima ruby-httpclient ruby-kgio ruby-spreadsheet ruby-svg-graph ; do
    if [ x$p = x$cur_pkg ] ; then
      use_eatmydata=0
      break
    fi
  done
fi

if [ $use_eatmydata -eq 1 ] ; then
  if [ -z "$LD_PRELOAD" ]; then
    LD_PRELOAD=/usr/lib/libeatmydata/libeatmydata.so
  else
    LD_PRELOAD="$LD_PRELOAD":/usr/lib/libeatmydata/libeatmydata.so
  fi
  export LD_PRELOAD
fi

#PBUILDERSATISFYDEPENDSCMD="/usr/lib/pbuilder/pbuilder-satisfydepends-classic"
#PBUILDERSATISFYDEPENDSOPT="--control ../*.dsc"
PBUILDERSATISFYDEPENDSCMD="/usr/bin/pbuilder-deps-wrapper.sh"
BINDMOUNTS="$BINDMOUNTS /run/shm"
EOF
if [ -e $HOME/.pbuilderrc ] ; then
  # abort if different file exists already
  diff $HOME/.pbuilderrc $HOME/.pbuilderrc.tmp
fi
mv $HOME/.pbuilderrc.tmp $HOME/.pbuilderrc

# from http://www.hermann-uwe.de/blog/rebuilding-the-whole-debian-archive-using-the-open64-compiler
sudo apt-get install cowbuilder grep-dctrl wget devscripts gcc \
	debian-keyring debian-archive-keyring screen eatmydata
sudo cowbuilder --create --distribution wheezy --mirror ftp://ftp.uk.debian.org/debian \
  --basepath $cow_base  \
  --debootstrapopts "--keyring=/usr/share/keyrings/debian-archive-keyring.gpg"
# cowbuilder or debootstrap bug: these umount /run/shm for some reason
sudo mount -t tmpfs -o nosuid,nodev none /run/shm

real_gcc=`readlink -f $cow_base/usr/bin/gcc`
if [ ! -f "$real_gcc" ] ; then
  echo "GCC not found"
  exit 1
fi
cat > $cow_base/tmp/gcc-wrapper <<"EOF"
#!/bin/bash

set -e
ulimit -S -v 16000000 || true
trap "rm -f /tmp/wrapper-$$" EXIT

touch /tmp/wrapper-$$
XXgccXX "$@"

# http://stackoverflow.com/questions/3586888/how-do-i-find-the-top-level-parent-pid-of-a-given-process-using-bash
function parent_is_wrapper {
  # Look up the parent of the given PID.
  pid=${1:-$$}
  stat=($(</proc/${pid}/stat))
  ppid=${stat[3]}

  if [ -f /tmp/wrapper-$ppid ] ; then
    return 0
  elif [ ${ppid} -eq 1 ] ; then
    return 1
  fi

  parent_is_wrapper ${ppid}
}
# exit if called from wrapper
if parent_is_wrapper ; then
  exit 0
fi

ofiles=""
objfiles=""
source_args=""
compile_only=0
ofile_next=0
lang_next=0
skip_next=0
has_lfl=""
has_lf2c=""
use_ld=0
include_next=0
fpch_preproc=""
for o in "$@" ; do
  if [ $skip_next -eq 1 ] ; then
    skip_next=0
    continue
  fi
  if [ $ofile_next -eq 1 ] ; then
    ofiles="$o"
    ofile_next=0
    continue
  fi
  if [ $lang_next -eq 1 ] ; then
    if [ "$o" = "c++" ] ; then
      exit 0
    elif [ "$o" = "objective-c" ] ; then
      exit 0
    fi
    lang_next=0
    # don't ignore $o (no continue), might also be relevant option
  fi
  if [ $include_next -eq 1 ] ; then
    if [ -d "$o.gch" ] ; then
      fpch_preproc="-fpch-preprocess"
    fi
    include_next=0
    continue
  fi
  case "$o" in
    -E) exit 0 ;;
    -S) exit 0 ;;
    -MM) exit 0 ;;
    -M) exit 0 ;;
    -MT) skip_next=1 ;;
    -MQ) skip_next=1 ;;
    -Xlinker) skip_next=1 ;;
    -o) ofile_next=1 ;;
    -o*) ofiles="`echo $o | cut -b3-`" ;;
    -c) compile_only=1 ;;
    -lfl) has_lfl="/tmp/libflmain.c" ;;
    -lf2c) has_lf2c="/tmp/libf2cmain.c" ;;
    -x) lang_next=1 ;;
    -Wl,-r) use_ld=1 ;;
    -Wl,-Ttext) exit 0 ;; # we don't really deal with sections starting at special addresses
    -Wl,-Ttext=*) exit 0 ;; # we don't really deal with sections starting at special addresses
    -include) include_next=1 ;;
    -*) true ;;
    *.o|*.so.[0-9]|*.so.[0-9].[0-9]|*.so.[0-9].[0-9].[0-9]|*.so.[0-9].[0-9].[0-9][0-9]) objfiles+=" $o" ;;
    *.c) source_args+=" $o" ;;
    *.i) source_args+=" $o" ;;
  esac
done
if [ -z "$source_args" -a -z "$objfiles" ] ; then
  exit 0
fi
  
if [ -z "$ofiles" ] ; then
  if [ $compile_only -eq 0 ] ; then
    ofiles="a.out"
  else
    for f in $source_args ; do
      ofiles+=" `basename "$f" | sed 's/\..$/.o/'`"
    done
  fi
fi

if [ -n "$objfiles" -a -z "$source_args" ] ; then
  some_gb=0
  for f in $objfiles ; do
    if objdump -h -j goto-cc "$f" > /dev/null 2<&1 ; then
      some_gb=1
    fi
  done
  if [ $some_gb -eq 0 ] ; then
    exit 0
  fi
fi

for f in $ofiles ; do
  if [ ! -e "$f" ] ; then
    echo "GCC did not create $f"
    exit 1
  elif [ "$f" = "/dev/null" ] ; then
    continue
  fi
  mv "$f" "$f.gcc-binary"
done

likely_has_main=""
for f in $objfiles ; do
  if [ ! -e "$f" ] ; then
    echo "GCC did not create $f"
    exit 1
  fi
  if nm -B "$f" 2>/dev/null | awk '{ print $2":"$3 }' | grep -q "^T:main$" ; then
    likely_has_main="$f"
    has_lfl=""
    has_lf2c=""
  fi
done
    
if [ -n "$has_lfl$has_lf2c" ] && [ "$ofiles" = "conftest" ] && \
    egrep -q '^[[:space:]]*(int[[:space:]]|void[[:space:]]|)[[:space:]]*main' $source_args > /dev/null 2>&1 ; then
  has_lfl=""
  hs_lf2c=""
fi

for f in $objfiles ; do
  if echo "$f" | egrep -q '^(/usr|/lib)' ; then
    continue
  fi
  if ! objdump -h -j goto-cc "$f" > /dev/null 2<&1 ; then
    if [ "$f" = "$likely_has_main" ] ; then
      echo "WARNING: GOTO-CC had not created $f, building binary containing main"
      echo "int main(int argc, char* argv[]) { return 0; }" > /tmp/empty-$$.c
    else
      echo "WARNING: GOTO-CC had not created $f, building empty binary"
      touch /tmp/empty-$$.c
    fi
    opt_m=""
    if file "$f" | grep -q 32-bit ; then
      opt_m="-m32"
    fi
    goto-cc $opt_m -o /tmp/empty-$$.o -c /tmp/empty-$$.c
    rm /tmp/empty-$$.c
    if ! objcopy --add-section goto-cc=/tmp/empty-$$.o "$f" ; then
      mv "$f" "$f.gcc-binary"
      mv /tmp/empty-$$.o "$f"
    fi
    use_ld=1
  fi
done

if [ -n "$has_lfl" ] ; then
  cat > $has_lfl <<"EOT"
/* flex/libmain.c */
extern int yylex ();

int     main (argc, argv)
     int     argc;
     char   *argv[];
{
	while (yylex () != 0) ;

	return 0;
}
EOT
fi

if [ -n "$has_lf2c" ] ; then
  cat > $has_lf2c <<"EOT"
/* libf2c2/main.c */
int xargc;
char **xargv;

extern void f_init(void);
extern int MAIN__(void);
 int
main(int argc, char **argv)
{
xargc = argc;
xargv = argv;
f_init();
MAIN__();
}
EOT
fi

if [ -n "$source_args" ] ; then
  use_ld=0
fi

if [ $use_ld -eq 0 ] ; then
  goto-cc "$@" $has_lfl $has_lf2c $fpch_preproc
else
  goto-ld "$@"
fi

for f in $ofiles ; do
  if [ ! -e "$f" ] ; then
    echo "GOTO-CC did not create $f"
    exit 1
  elif [ "$f" = "/dev/null" ] ; then
    continue
  fi
  if [ "`basename "$f"`" != "conftest" ] ; then
    gbfile="`readlink -f "$f"`"
    gbfile="`echo "$gbfile" | sed 's#/build/[^/]*#&/goto-binaries#'`"
    gbfile="`echo "$gbfile" | sed 's#^/tmp/#&goto-binaries/#'`"
    gbfile="`echo "$gbfile" | sed 's#^/var/tmp/#&goto-binaries/#'`"
    mkdir -p "`dirname "$gbfile"`"
    mv "$f" "$gbfile"
    mv "$f.gcc-binary" "$f"
    if [ $use_ld -eq 0 ] ; then
      # if only linking was done, a goto-cc section will be present already (but unusable)
      if objdump -h -j goto-cc "$f" > /dev/null 2<&1 ; then
        objcopy -R goto-cc "$f"
      fi
      objcopy --add-section goto-cc="$gbfile" "$f"
    fi

    if [ -n "$objfiles" ] ; then
      echo "$f: $objfiles" >> "$gbfile.linked"
    fi
  else
    mv "$f.gcc-binary" "$f"
  fi
done

for f in $objfiles ; do
  if [ -f "$f.gcc-binary" ] ; then
    mv "$f.gcc-binary" "$f"
  fi
done
EOF
real_gcc_bn=`basename $real_gcc`
sed -i "s/XXgccXX/$real_gcc_bn.orig/" $cow_base/tmp/gcc-wrapper

real_ld=`readlink -f $cow_base/usr/bin/ld`
if [ ! -f "$real_ld" ] ; then
  echo "ld not found"
  exit 1
fi
cat > $cow_base/tmp/ld-wrapper <<"EOF"
#!/bin/bash

set -e
ulimit -S -v 16000000 || true
trap "rm -f /tmp/wrapper-$$" EXIT

touch /tmp/wrapper-$$
XXldXX "$@"

# http://stackoverflow.com/questions/3586888/how-do-i-find-the-top-level-parent-pid-of-a-given-process-using-bash
function parent_is_wrapper {
  # Look up the parent of the given PID.
  pid=${1:-$$}
  stat=($(</proc/${pid}/stat))
  ppid=${stat[3]}

  if [ -f /tmp/wrapper-$ppid ] ; then
    return 0
  elif [ ${ppid} -eq 1 ] ; then
    return 1
  fi

  parent_is_wrapper ${ppid}
}
# exit if called from wrapper
if parent_is_wrapper ; then
  exit 0
fi

ofiles=""
objfiles=""
ofile_next=0
skip_next=0
for o in "$@" ; do
  if [ $skip_next -eq 1 ] ; then
    skip_next=0
    continue
  fi
  if [ $ofile_next -eq 1 ] ; then
    ofiles="$o"
    ofile_next=0
    continue
  fi
  case "$o" in
    -Ttext) exit 0 ;; # we don't really deal with sections starting at special addresses
    -Ttext=*) exit 0 ;; # we don't really deal with sections starting at special addresses
    -soname|-h) skip_next=1 ;;
    -o) ofile_next=1 ;;
    -o*) ofiles="`echo $o | cut -b3-`" ;;
    -*) true ;;
    *.o|*.so.[0-9]|*.so.[0-9].[0-9]|*.so.[0-9].[0-9].[0-9]|*.so.[0-9].[0-9].[0-9][0-9]) objfiles+=" $o" ;;
  esac
done
if [ -z "$objfiles" ] ; then
  exit 0
fi
  
if [ -z "$ofiles" ] ; then
  ofiles="a.out"
fi

some_gb=0
for f in $objfiles ; do
  if objdump -h -j goto-cc "$f" > /dev/null 2<&1 ; then
    some_gb=1
  fi
done
if [ $some_gb -eq 0 ] ; then
  exit 0
fi

for f in $ofiles ; do
  if [ ! -e "$f" ] ; then
    echo "ld did not create $f"
    exit 1
  elif [ "$f" = "/dev/null" ] ; then
    continue
  fi
  mv "$f" "$f.gcc-binary"
done

for f in $objfiles ; do
  if [ ! -e "$f" ] ; then
    echo "GCC did not create $f"
    exit 1
  fi
  if echo "$f" | egrep -q '^(/usr|/lib)' ; then
    continue
  fi
  if ! objdump -h -j goto-cc "$f" > /dev/null 2<&1 ; then
    echo "WARNING: GOTO-CC had not created $f, building empty binary"
    touch /tmp/empty-$$.c
    opt_m=""
    if file "$f" | grep -q 32-bit ; then
      opt_m="-m32"
    fi
    goto-cc $opt_m -o /tmp/empty-$$.o -c /tmp/empty-$$.c
    rm /tmp/empty-$$.c
    if ! objcopy --add-section goto-cc=/tmp/empty-$$.o "$f" ; then
      mv "$f" "$f.gcc-binary"
      mv /tmp/empty-$$.o "$f"
    fi
  fi
done

goto-ld "$@"

for f in $ofiles ; do
  if [ ! -e "$f" ] ; then
    echo "GOTO-LD did not create $f"
    exit 1
  elif [ "$f" = "/dev/null" ] ; then
    continue
  fi
  if [ "`basename "$f"`" != "conftest" ] ; then
    gbfile="`readlink -f "$f"`"
    gbfile="`echo "$gbfile" | sed 's#/build/[^/]*#&/goto-binaries#'`"
    gbfile="`echo "$gbfile" | sed 's#^/tmp/#&goto-binaries/#'`"
    gbfile="`echo "$gbfile" | sed 's#^/var/tmp/#&goto-binaries/#'`"
    mkdir -p "`dirname "$gbfile"`"
    mv "$f" "$gbfile"
    mv "$f.gcc-binary" "$f"

    if [ -n "$objfiles" ] ; then
      echo "$f: $objfiles" >> "$gbfile.linked"
    fi
  else
    mv "$f.gcc-binary" "$f"
  fi
done

for f in $objfiles ; do
  if [ -f "$f.gcc-binary" ] ; then
    mv "$f.gcc-binary" "$f"
  fi
done
EOF
real_ld_bn=`basename $real_ld`
sed -i "s/XXldXX/$real_ld_bn.orig/" $cow_base/tmp/ld-wrapper

# workaround for http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=694404
cat > $cow_base/tmp/pbuilder-deps-wrapper.sh <<"EOF"
#!/bin/sh

/usr/lib/pbuilder/pbuilder-satisfydepends-classic --control ../*.dsc $@
EOF

wget http://dkr-build.cs.ox.ac.uk:8080/job/CBMC-trunk/ws/src/goto-cc/goto-cc -O $cow_base/tmp/goto-cc
chmod a+rx $cow_base/tmp/goto-cc

real_gcc_chroot="`echo $real_gcc | sed "s#^$cow_base##"`"
real_ld_chroot="`echo $real_ld | sed "s#^$cow_base##"`"
echo " \
sed -i 's/wheezy main/wheezy main contrib non-free/' /etc/apt/sources.list ; \
apt-get update ; \
apt-get install eatmydata adduser ; \
addgroup --system --gid 1234 pbuilder ; \
adduser --system --no-create-home --uid 1234 --gecos pbuilder --disabled-login pbuilder ; \
mv $real_gcc_chroot $real_gcc_chroot.orig ; \
mv /tmp/gcc-wrapper $real_gcc_chroot ; \
chmod a+rx $real_gcc_chroot ; \
mv $real_ld_chroot $real_ld_chroot.orig ; \
mv /tmp/ld-wrapper $real_ld_chroot ; \
chmod a+rx $real_ld_chroot ; \
mv /tmp/pbuilder-deps-wrapper.sh /usr/bin ; \
chmod a+rx /usr/bin/pbuilder-deps-wrapper.sh ; \
mv /tmp/goto-cc /usr/bin/goto-cc ; \
cp /usr/bin/goto-cc /usr/bin/goto-ld ; \
exit" | sudo cowbuilder --login --save-after-login --basepath $cow_base

cp /usr/share/doc/pbuilder/examples/rebuild/{buildall,getlist} .
sed -i 's#any#linux-any| any#' getlist
sed -i 's#^MIRROR=.*$#MIRROR=ftp://ftp.uk.debian.org#' buildall getlist
sed -i "s#^BASEPATH=.*\$#BASEPATH=\"$cow_base\"#" buildall
sed -i 's#mkdir -p \$BUILDDIR/\$PACKAGE$#rm -rf $BUILDDIR/$PACKAGE ; mkdir -p $BUILDDIR/$PACKAGE#' buildall
sed -i 's/dget/umask 0022; export DEB_VENDOR=Debian; dget -u/' buildall
sed -i 's#pdebuild#export -n DISPLAY; pdebuild#' buildall
sed -i 's#rm -rf \$PACKAGE#if [ ! -e $LOGDIR/failed-$PACKAGE ] ; then rm -rf $PACKAGE/$PACKAGE-* $PACKAGE/result $PACKAGE/*.deb ; if [ -d $PACKAGE/goto-binaries ] ; then cd $PACKAGE ; tar cjf goto-binaries.tar.bz2 goto-binaries ; rm -rf goto-binaries ; cd .. ; fi ; fi#' buildall
sed -i "s#^while read package.*#while read package; do if [ \$\(\(\`df /home | tail -1 | awk '{ print \$4 }'\`/1024\)\) -lt 2000 ] ; then break ; fi#" buildall

mkdir -p $HOME/.gnupg

./getlist wheezy
#screen -d -m ./buildall list.wheezy.amd64 wheezy
#sleep 1
#screen -d -m ./buildall list.wheezy.amd64 wheezy
#sleep 1
#screen -d -m ./buildall list.wheezy.amd64 wheezy
#sleep 1
#screen -d -m ./buildall list.wheezy.amd64 wheezy
#sleep 1
#screen -d -m ./buildall list.wheezy.amd64 wheezy
#sleep 1
#screen -d -m ./buildall list.wheezy.amd64 wheezy

