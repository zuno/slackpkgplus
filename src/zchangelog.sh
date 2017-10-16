### Note about ZChangeLog ##
#
#
# It track all repositories changes in /var/lib/slackpkg/RepoChangeLog.txt
# everytime you run 'slackpkg update' so you will have a global changelog.
#
# WARNING: This tool is in an embrional state. However it does not affect
#          the correct slackpkg+ working. But you need to install it manually
#          if you want use it.
#
# To install it run (as root):
# $ ln -sf /usr/libexec/slackpkg/zchangelog.sh /usr/libexec/slackpkg/functions.d/
#
# To uninstall it run (as root):
# $ rm /usr/libexec/slackpkg/functions.d/zchangelog.sh
#
# By default after run 'slackpkg update' ZChangeLog print the changes in
# output. If you dislike it add 'SHOW_ZCHANGELOGS=no' to slackpkgplus.conf
#

test -n "$(declare -f cleanup)" # || return
eval "${_/cleanup/cleanup_orig}"

function pkglistdiff (){
  diff $WORKDIR/pkglist.copy $WORKDIR/pkglist|
    grep -e "^>" -e "^<"|
    sed 's/SLACKPKGPLUS_//'|
    sort -k2|
    awk '{print $1,$2":"$3,$2,$3,$4,$5,$6,$9}'|
    uniq -f1 -u|
    awk '{print $1,$8,$7,$6,$5,$4,$3,$2}'|
    grep -v /
} 

function makepkglog(){
  if [ -z "$TMPDIR" ];then TMPDIR=/tmp;fi
  if [ -z "$WORKDIR" ];then WORKDIR=/var/lib/slackpkg;fi
  IGNORE="$( (
    cat $WORKDIR/pkglist.copy|awk '{print $1}'|sort -u|sed 's/SLACKPKGPLUS_//'|sed 's/^/Removed /'
    cat $WORKDIR/pkglist     |awk '{print $1}'|sort -u|sed 's/SLACKPKGPLUS_//'|sed 's/^/Added /'
    )|sort -k2|uniq -f1 -u)"
  echo "$IGNORE"|awk '{print $1": "$2}'|column -t |sort -k2|grep ...&&echo
  echo "$IGNORE"|awk '{print " "$2" "}'|grep ... >$TMPDIR/ignorerepos

  (
    pkglistdiff |uniq -f5 -u |awk '{if ($1=="<"){ print "Removed: "$7" :: "$6"-"$5"-"$4"-"$3"."$2 }else{ print "Added: "$7" :: "$6"-"$5"-"$4"-"$3"."$2 } }'
    pkglistdiff |uniq -f5 -D |uniq -f4 -D|grep '>'|awk '{print "Rebuilt: "$7" :: "$6"-"$5"-"$4"-"$3"."$2}'
    pkglistdiff |uniq -f5 -D |uniq -f4 -u|grep '>'|awk '{print "Upgraded: "$7" :: "$6"-"$5"-"$4"-"$3"."$2}'
  )|sort -k2|column -t| grep -v -f $TMPDIR/ignorerepos

}

function cleanup(){
  if [ "$CMD" == "update" ]&&[ -e "$WORKDIR/pkglist" ];then
    if [ ! -e "$WORKDIR/pkglist.copy" ];then
      touch -t 197001010101 $WORKDIR/pkglist.copy
      touch $WORKDIR/RepoChangeLog.txt
    fi
    if [ $WORKDIR/pkglist -nt $WORKDIR/pkglist.copy ];then
      date > $TMPDIR/RepoChangeLog.txt
      echo "----------------------------------" >> $TMPDIR/RepoChangeLog.txt
      makepkglog >> $TMPDIR/RepoChangeLog.txt


      if ! tail -1 $TMPDIR/RepoChangeLog.txt|grep -q -- --------- ;then
        echo >> $TMPDIR/RepoChangeLog.txt
        echo "==================================" >> $TMPDIR/RepoChangeLog.txt
        if [ "$SHOW_ZCHANGELOGS" != "no" ];then
          cat $TMPDIR/RepoChangeLog.txt
        fi
        cat $WORKDIR/RepoChangeLog.txt >> $TMPDIR/RepoChangeLog.txt
        cp $TMPDIR/RepoChangeLog.txt $WORKDIR/RepoChangeLog.txt
      fi
      cp $WORKDIR/pkglist $WORKDIR/pkglist.copy
    fi
  fi
  cleanup_orig
}

