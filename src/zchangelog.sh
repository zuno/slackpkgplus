### Note about ZChangeLog ##
#
#
# It track all repositories changes in /var/lib/slackpkg/RepoChangeLog.txt
# everytime you run 'slackpkg update' so you will have a global changelog.
#
# example:
#   Wed Feb 24 22:17:41 CET 2021
#   ----------------------------------
#   Added:  testing
#
#   Upgraded:  alienbob      ::  chromium-88.0.4324.190-x86_64-1alien.txz
#   Added:     extra         ::  php8-8.0.2-x86_64-1.txz
#   Upgraded:  slackpkgplus  ::  slackpkg+-1.7.2-noarch-1mt.txz
#   Upgraded:  slackware64   ::  Cython-0.29.22-x86_64-1.txz
#   Upgraded:  slackware64   ::  autoconf-archive-2021.02.19-noarch-1.txz
#   Rebuilt:   slackware64   ::  bind-9.16.11-x86_64-3.txz
#   Upgraded:  slackware64   ::  bluedevil-5.21.1-x86_64-1.txz

#
# WARNING: This tool is in an embrional state. However it does not affect
#          the correct slackpkg+ working. But you need to install it manually
#          if you want use it.
#
# To use it put PLUGIN_ZCHANGELOG=enable
# in /etc/slackpkg/slackpkgplus.conf
#
# After run 'slackpkg update' ZChangeLog cat print the changes in output
# if you set 'PLUGIN_ZCHANGELOG_SHOW=on' to slackpkgplus.conf
#

if [ "$PLUGIN_ZCHANGELOG" == "enable" ];then

test -n "$(declare -f cleanup)" # || return
eval "${_/cleanup/cleanup_orig}"

function pkglistdiff (){
  diff $WORKDIR/pkglist.copy $WORKDIR/pkglist|grep -v " SBO_"|
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
    cat $WORKDIR/pkglist.copy|grep -v ^SBO_|awk '{print $1}'|sort -u|sed 's/SLACKPKGPLUS_//'|sed 's/^/Removed /'
    cat $WORKDIR/pkglist     |grep -v ^SBO_|awk '{print $1}'|sort -u|sed 's/SLACKPKGPLUS_//'|sed 's/^/Added /'
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
        if [ "$PLUGIN_ZCHANGELOG_SHOW" == "on" ];then
          cat $TMPDIR/RepoChangeLog.txt
        fi
        cat $WORKDIR/RepoChangeLog.txt >> $TMPDIR/RepoChangeLog.txt
        cp $TMPDIR/RepoChangeLog.txt $WORKDIR/RepoChangeLog.txt
      fi
      cat $WORKDIR/pkglist|grep -v ^SBO_ > $WORKDIR/pkglist.copy
    fi
  fi
  cleanup_orig
}

fi
