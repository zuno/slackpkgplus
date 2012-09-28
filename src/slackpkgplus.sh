declare -A MIRRORPLUS
if [ -e /etc/slackpkg/slackpkgplus.conf ];then
  . /etc/slackpkg/slackpkgplus.conf
fi
if [ "$SLACKPKGPLUS" = "on" ];then
  # If CHECKGPG is "on", the system will FAIL the GPG signature of extra repository
  # Use MD5 check instead
  CHECKGPG=off

  REPOPLUS=${!MIRRORPLUS[*]}
  PRIORITY=( ${PRIORITY[*]} slackpkgplus_$(echo $REPOPLUS|sed 's/ / slackpkgplus_/g') )

  function getfile(){
    local URLFILE
    URLFILE=$1

    if echo $URLFILE|grep -q /slackpkgplus_;then
      PREPO=$(echo $URLFILE|sed -r 's#^.*/slackpkgplus_([^/]+)/.*$#\1#')
      URLFILE=$(echo $URLFILE|sed "s#^.*/slackpkgplus_$PREPO/#${MIRRORPLUS[$PREPO]}#")
    fi
    
    $DOWNLOADER $2 $URLFILE
    if [ $(basename $1) = "CHECKSUMS.md5" ];then
      for PREPO in $REPOPLUS;do
	$DOWNLOADER $2-tmp ${MIRRORPLUS[${PREPO/slackpkgplus_}]}CHECKSUMS.md5
	egrep -e ^[a-f0-9]{32} $2-tmp|sed -r "s# \./# ./slackpkgplus_$PREPO/#" >> $2
      done
    fi
    if [ $(basename $1) = "ChangeLog.txt" ];then
      for PREPO in $REPOPLUS;do
	$DOWNLOADER $2-tmp ${MIRRORPLUS[${PREPO/slackpkgplus_}]}ChangeLog.txt
	echo $PREPO $(md5sum $2-tmp|awk '{print $1}') >>$2
	rm $2-tmp
      done
    fi

  }

fi
