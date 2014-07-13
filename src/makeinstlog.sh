#!/bin/bash

CONF=${CONF:-/etc/slackpkg} # needed if you're running slackpkg 2.28.0-12

. $CONF/slackpkg.conf

if [ -e $WORKDIR/pkglist ];then
  cp $WORKDIR/pkglist $WORKDIR/pkglist.tmp
fi
(

  (
    cd $ROOT/var/log/removed_packages
    ( ls -l --full-time|tail +2|cut -c11-|sed -r -e 's/\.[0-9]{9}//' -e 's,-,/,' -e 's,-,/,'|awk '{print $8,$5,$6}'
      grep -m1 'PACKAGE LOCATION:' * 2>/dev/null|sed -r 's/:PACKAGE LOCATION:.*(\.t.z)/ \1/'
    )|sort|awk '{if(x=!x){printf("%s ", $2)}else{print $2,$3,$1}}'    \
     |sed -e 's/$/ removed/' -e 's/-upgraded-.*/ upgraded/'|awk '{print $2,$3,$4,$1,$5}'
    cd $ROOT/var/log/packages
    ( ls -l --full-time|tail +2|cut -c11-|sed -r -e 's/\.[0-9]{9}//' -e 's,-,/,' -e 's,-,/,'|awk '{print $8,$5,$6}'
      grep -m1 'PACKAGE LOCATION:' * 2>/dev/null|sed -r 's/:PACKAGE LOCATION:.*(\.t.z)/ \1/'
    )|sort|awk '{if(x=!x){printf("%s ", $2)}else{print $2,$3,$1}}'    \
     |sed -e 's/$/ installed/'|awk '{print $2,$3,$4,$1,$5}'
  )| sed -r -e 's/^([^ ]+) ([^ ]+) (.*)-([^-]+)-([^-]+)-([^ ]+) (\.t.z) (.*)/\1 \2 \3 \3-\4-\5-\6 \7 \8/'|sort|awk '{
	       if (!p[$3])        { print $1" "$2" installed:   "$4$5"  []"               ; p[$3]=$4 }
	  else if ($5=="removed") { print $1" "$2" removed:     "$4                       ; p[$3]=0  }
	  else if (p[$3]==$4)     { print $1" "$2" reinstalled: "$4$5"  []"                          }
	  else                    { print $1" "$2" upgraded:    "$4$5"  []  (was "p[$3]")"; p[$3]=$4 }
     }'

  cat $WORKDIR/install.log 2>/dev/null|grep -v '\[\]'

)|sort -r|awk '{if(!a[$1$2$3$4]++)print}'|tac >$WORKDIR/install.log.tmp

if [ ! -e $WORKDIR/pkglist.tmp ];then
  if [ -e $WORKDIR/pkglist ];then
    cp $WORKDIR/pkglist $WORKDIR/pkglist.tmp
  fi
fi
if [ ! -e $WORKDIR/pkglist.tmp ];then
  echo "pkglist does not exists; unable to try repository detect"
  mv $WORKDIR/install.log.tmp $WORKDIR/install.log.new
else
  cat $WORKDIR/install.log.tmp |while read a;do 
      P=$(echo $a|awk '{print $4}')
      R=$(grep -m1 \
	    "$(echo $P|awk -f /usr/libexec/slackpkg/pkglist.awk | awk '{print " "$1" .* "$3" "$4"$"}'| sed -r 's/ [0-9]+([^\$]*)\$/ [0-9]\\+\1 /')" \
	    $WORKDIR/pkglist.tmp|awk '{print $1}'|sed 's/SLACKPKGPLUS_//'
	 )
      echo "$a"|sed "s/\[\]/[$R]/"
  done > $WORKDIR/install.log.new
  rm $WORKDIR/install.log.tmp
  rm $WORKDIR/pkglist.tmp
fi
mv $WORKDIR/install.log.new $WORKDIR/install.log
echo "An install log was created in $WORKDIR/install.log"
