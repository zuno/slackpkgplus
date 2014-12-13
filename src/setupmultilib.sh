#!/bin/bash

CONF=${CONF:-/etc/slackpkg} # needed if you're running slackpkg 2.28.0-12

. $CONF/slackpkg.conf

cd $(dirname $(readlink -f $0))
if [ ! -e repositories.txt ];then
  echo "Fatal. repositories.txt not found!"
  exit 1
fi

ISX64=$(ls $ROOT/var/log/packages/aaa_base-*-x86_64-*|wc -l)
if [ $ISX64 -ne 1 ];then
  echo "Slackware multilib's are supported only from slackware x86_64!"
  exit 1
fi
SVER=$(grep -v ^\# $CONF/mirrors|sed -r 's,^.*/slackware64-(current|14.1|14.0|13.37|13.0)/,\1,'|head -1)
if [ -z "$SVER" ];then
  echo "I can't detect your Slackware version."
  echo "Which Slackware version are you running? (current/14.1/14.0/13.37/13.0)"
  read $SVER
fi
if ! echo $SVER|egrep -q '^(current|14.1|14.0|13.37|13.0)$';then
  echo "Invalid Slackware version ($SVER)"
  exit 1
fi

if grep -q -e '^PKGS_PRIORITY=.* multilib:\.\* .*$' -e '^MIRRORPLUS..multilib..=.*multilib.*' $CONF/slackpkgplus.conf;then
  echo "slackpkg+ seems to be already configured for multilib support. Would you like to remove multilib support from the configuration? (y/N)"
  read ANS
  if [ "$ANS" == "y" -o "$ANS" == "Y" ];then
    cp $CONF/slackpkgplus.conf $CONF/slackpkgplus.conf.backup
    sed -i -r \
      -e 's/^PKGS_PRIORITY=(.*) multilib[^ ]* (.*)$/PKGS_PRIORITY=\1 \2/' \
      -e 's/^(PKGS_PRIORITY=\( +\).*)$/#\1/' \
      -e 's/^(MIRRORPLUS..multilib..=.*multilib.*)$/#\1/' \
      -e 's/^REPOPLUS=(.*) multilib (.*)/REPOPLUS=\1 \2/' \
      -e 's/^(REPOPLUS=\( +\).*)$/#\1/' $CONF/slackpkgplus.conf
    echo "Multilib support has been removed from slackpkg+. Now you need to remove the installed packages (using slackpkg)."
    echo "Would you like this script to run slackpkg for you and remove the Multilib packages? (y/N)"
    read ANS
    if [ "$ANS" == "y" -o "$ANS" == "Y" ];then
      slackpkg update
      slackpkg upgrade gcc glibc
      slackpkg remove multilib
      echo "Multilib removed!!"
      exit 0
    else
      echo "To remove installed packages type:"
      echo "# slackpkg update"
      echo "# slackpkg upgrade gcc glibc"
      echo "# slackpkg remove multilib"
      exit 0
    fi
  else
    echo "Aborted"
    exit 1
  fi
fi

echo "Would you like to setup slackpkg+ to add multilib support? (y/N)"
read ANS
if [ "$ANS" == "y" -o "$ANS" == "Y" ];then
  MULTILIBREPO="MIRRORPLUS['multilib']="$(grep -m1 '> multilib: ' repositories.txt|awk '{print $3}'|sed "s/{.*}/$SVER/")
  cp $CONF/slackpkgplus.conf $CONF/slackpkgplus.conf.backup
  if grep -q ^PKGS_PRIORITY= $CONF/slackpkgplus.conf;then
    sed -i -r -e 's/^PKGS_PRIORITY=\( (.*) \)/PKGS_PRIORITY=( multilib:.* \1 )/' $CONF/slackpkgplus.conf
  else
    sed -i -r -e '1,/^#PKGS_PRIORITY=.*$/s/^(#PKGS_PRIORITY=.*)$/\1\nPKGS_PRIORITY=( multilib: )\n/' $CONF/slackpkgplus.conf
  fi
  sed -i -r -e 's|^(PKGS_PRIORITY=.*)$|\1\n'"$MULTILIBREPO|" $CONF/slackpkgplus.conf
  sed -i.backup -r -e 's/^(\[0-9\]\+compat32)$/\#\1/' $CONF/blacklist
  echo "slackpkg+ is now configured for multilib support."
  echo "Do you want to install the multilib now? (y/N)"
  read ANS
  if [ "$ANS" == "y" -o "$ANS" == "Y" ];then
    slackpkg update gpg
    slackpkg update
    slackpkg upgrade multilib
    COMPATPKGS=$(
      cd $ROOT/var/log/packages
      ls | rev |cut -f4- -d-|rev|sed -e 's/^/^slackware64 /' -e 's/$/ /' > /tmp/installed_packages1
      grep -f /tmp/installed_packages1 $WORKDIR/pkglist|awk '{print "SLACKPKGPLUS_multilib "$2"-compat32 "}' > /tmp/installed_packages2
      grep -f /tmp/installed_packages2 $WORKDIR/pkglist|awk '{print "multilib:"$2}'
    )
    slackpkg install $COMPATPKGS
    echo "Multilib installed"
  else
    echo "To install multilib type:"
    echo "# slackpkg update gpg"
    echo "# slackpkg update"
    echo "# slackpkg upgrade gcc glibc"
    echo "# slackpkg install multilib"
  fi
  echo "To keep multilib updated, simply type:"
  echo "# slackpkg upgrade-all"
  if [ "$SVER" == "current" ];then
    echo "Remember... When you see NEW packages with 'slackpkg install-new' command,"
    echo "you may need to install the related multilib package"
  fi
  exit 0
else
  echo "Aborted"
  exit 1
fi
