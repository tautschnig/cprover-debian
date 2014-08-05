#!/bin/bash

set -e

rm -rf jenkins
mkdir jenkins

cp -a ../jenkins/.{groovy,owner,subversion} jenkins

for f in `ls ../jenkins | grep -v '.log$' | \
    egrep -v '^(jobs|secrets|identity.key.enc|credentials.xml|secret.key|secret.key.not-so-secret)$'` ; do
  cp -a ../jenkins/$f jenkins/
done

rm -rf jenkins/plugins/*.bak jenkins/logs/*

sed -i 's#<apiToken>.*</apiToken>#<apiToken>x</apiToken>#' jenkins/users/*/config.xml
sed -i 's#<passwordHash>.*</passwordHash>#<passwordHash>x</passwordHash>#' jenkins/users/*/config.xml

mkdir jenkins/jobs
for f in `find ../jenkins/jobs/JOB-* -name config.xml` ; do
  dn=`echo $f | sed 's/^\.\.\///' | sed 's/\/config.xml$//'`
  mkdir -p $dn
  cp $f $dn/
done

