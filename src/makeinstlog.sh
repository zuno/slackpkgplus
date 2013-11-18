#!/bin/bash
WORKDIR=/var/lib/slackpkg
. /etc/slackpkg/slackpkg.conf

(

  (
    cd /var/log/removed_packages
    ( ls -l --full-time|tail +2|cut -c11-|sed -r -e 's/\.[0-9]{9}//' -e 's,-,/,' -e 's,-,/,'|awk '{print $8,$5,$6}'
      grep -m1 'PACKAGE LOCATION:' *|sed -r 's/:PACKAGE LOCATION:.*(\.t.z)/ \1/'
    )|sort|awk '{if(x=!x){printf("%s ", $2)}else{print $2,$3,$1}}'    \
     |sed -e 's/$/ removed/' -e 's/-upgraded-.*/ upgraded/'|awk '{print $2,$3,$4,$1,$5}'
    cd /var/log/packages
    ( ls -l --full-time|tail +2|cut -c11-|sed -r -e 's/\.[0-9]{9}//' -e 's,-,/,' -e 's,-,/,'|awk '{print $8,$5,$6}'
      grep -m1 'PACKAGE LOCATION:' *|sed -r 's/:PACKAGE LOCATION:.*(\.t.z)/ \1/'
    )|sort|awk '{if(x=!x){printf("%s ", $2)}else{print $2,$3,$1}}'    \
     |sed -e 's/$/ installed/'|awk '{print $2,$3,$4,$1,$5}'
  )| sed -r -e 's/^([^ ]+) ([^ ]+) (.*)-([^-]+)-([^-]+)-([^ ]+) (\.t.z) (.*)/\1 \2 \3 \3-\4-\5-\6 \7 \8/'|sort|awk '{
	       if (!p[$3])        { print $1" "$2" installed:   "$4$5"  []"               ; p[$3]=$4 }
	  else if ($5=="removed") { print $1" "$2" removed:     "$4                       ; p[$3]=0  }
	  else if (p[$3]==$4)     { print $1" "$2" reinstalled: "$4$5"  []"                          }
	  else                    { print $1" "$2" upgraded:    "$4$5"  []  (was "p[$3]")"; p[$3]=$4 }
     }'

  cat $WORKDIR/install.log|grep -v '\[\]'

)|sort -r|awk '{if(!a[$1$2$3$4]++)print}'|tac >$WORKDIR/install.log.new

if [ ! -e $WORKDIR/install.log ];then
  mv $WORKDIR/install.log.new $WORKDIR/install.log
  echo "An install log was created in $WORKDIR/install.log"
else
  echo "An install log was created in $WORKDIR/install.log.new"
fi
