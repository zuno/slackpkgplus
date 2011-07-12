if [ -e /etc/slackpkg/slackypkg.conf ];then
  . /etc/slackpkg/slackypkg.conf
fi
if [ "$SLACKY" = "on" ];then
  # If CHECKGPG is "on", the system will FAIL the GPG signature of slacky repository
  # Use MD5 check instead
  CHECKGPG=off
  PRIORITY[5]=slacky

  if [ "$SLACKVER" = auto ];then
    SLACKVER=slackware$(ls /var/log/packages/aaa_base-*|grep -o 64)-$(ls /var/log/packages/aaa_base-*|sed -r 's/.*aaa_base-([^-]+)-.*/\1/')
  fi
  SLACKYSOURCE=$SLACKYMIRROR/$SLACKVER/

  function getfile(){
    local URLFILE
    URLFILE=$1
    URLFILE=`echo $1|sed -r 's#/(development|games|graphic|hardware|libraries|multimedia|network|security|system|utilities)/#/slacky/\1/#' `
    URLFILE=`echo $URLFILE|sed "s#^.*/slacky/#$SLACKYSOURCE#"`
    echo -e "\t\t\tDownloading $URLFILE..."
    $DOWNLOADER $2 $URLFILE
    if [ $(basename $1) = "CHECKSUMS.md5" ];then
      $DOWNLOADER $2-slacky $SLACKYSOURCE/CHECKSUMS.md5
      egrep -e ^[a-f0-9]{32} $2-slacky >> $2
    fi
    if [ $(basename $1) = "ChangeLog.txt" ];then
      $DOWNLOADER $2-slacky $SLACKYSOURCE/ChangeLog.txt
      head -1 $2-slacky >> $2
    fi
  }


  if [ -e /var/lib/slackpkg/pkglist ];then
    tail -1 /var/lib/slackpkg/pkglist|grep -q ^slacky
    if [ $? -ne 0 ];then
      sed -r -i.bck \
	's/^(development|games|graphic|hardware|libraries|multimedia|network|security|system|utilities)/slacky/' \
	/var/lib/slackpkg/pkglist
    fi
  fi

fi
