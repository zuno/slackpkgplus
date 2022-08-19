[ -e /etc/slackpkg/gitslackpkg+.conf ]&&source /etc/slackpkg/gitslackpkg+.conf
if [ ! -z "$GITSLACKPKG" ]&&[ "$GITSLACKPKG" != "off" ]&&[ "$CMD" == "update" ];then

 if [ "${GITSLACKPKG:0:1}" = "/" ];then
  for fl in slackpkgplus.sh zchangelog.sh zlookkernel.sh aaa_gitslackpkg+.sh;do
    if [ -e "$GITSLACKPKG/$fl" ];then
      if ! ls -l /usr/libexec/slackpkg/functions.d/$fl|grep -q " $GITSLACKPKG/$fl$";then
        rm -f /usr/libexec/slackpkg/functions.d/$fl
        ln -sv $GITSLACKPKG/$fl /usr/libexec/slackpkg/functions.d/$fl
      fi
    fi
  done
 else
  CWD=`pwd`
  [ ! -e /usr/libexec/slackpkg/gitslackpkg ]&&mkdir /usr/libexec/slackpkg/gitslackpkg
  cd /usr/libexec/slackpkg/gitslackpkg
  if [ ! -e slackpkgplus ];then
    git clone https://github.com/zuno/slackpkgplus
  fi
  if [ ! -e slackpkgplus ];then
    echo "PROBLEM CONFIGURING GITHUB RELEASE $GITSLACKPKG (1)"
    cleanup
  fi
  cd slackpkgplus
  CURRBRANCH=$(git status|grep "On branch"|awk '{print $NF}')
  CURRLIST="$(ls -lR src/)"
  if [ "$CURRBRANCH" != "$GITSLACKPKG" ];then
    echo "Switching gitslackpkg from $CURRBRANCH to $GITSLACKPKG"
    git checkout $GITSLACKPKG
  fi
  CURRBRANCH=$(git status|grep "On branch"|awk '{print $NF}')
  if [ "$CURRBRANCH" != "$GITSLACKPKG" ];then
    echo "PROBLEM CONFIGURING GITHUB RELEASE $GITSLACKPKG (2)"
    cleanup
  fi
  echo "Looking for news on gitslackpkg+"
  git pull
  NEWLIST="$(ls -lR src/)"
  DIFFLIST="$(diff <(echo "$CURRLIST") <(echo "$NEWLIST"))"
  if [ -z "$DIFFLIST" ];then
    echo "No news on gitslackpkg+"
    echo
  else
    echo "Updating slackpkg+ from github"
    git log|head -3|grep -e ^commit -e ^Date
    cd src
    for fl in slackpkgplus.sh zchangelog.sh zlookkernel.sh aaa_gitslackpkg+.sh;do
      if [ ! -e $fl ];then continue;fi
      if ! diff -q $fl /usr/libexec/slackpkg/functions.d/$fl;then
        rm -f /usr/libexec/slackpkg/functions.d/$fl
        cp -v $fl /usr/libexec/slackpkg/functions.d/$fl
      fi
    done
    if echo "$DIFFLIST"|grep -q slackpkgplus.x;then
      echo
      echo "NOTICE: Configuration file changed in this release; be sure to update it"
    fi
    echo
    echo "INFO: slackpkg+ update from github. You need to rerun 'slackpkg update' again"
    cleanup
  fi
  cd $CWD
 fi
fi
