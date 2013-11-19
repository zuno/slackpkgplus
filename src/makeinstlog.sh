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

  cat $WORKDIR/install.log 2>/dev/null|grep -v '\[\]'

)|sort -r|awk '{if(!a[$1$2$3$4]++)print}'|tac >$WORKDIR/install.log.new

if [ "$1" == "-t" ];then
  if [ ! -e $WORKDIR/pkglist ];then
    echo "pkglist does not exists; unable to try repository detect"
    echo "An install log was created in $WORKDIR/install.log.new ; review it and rename in install.log"
  else
    cat $WORKDIR/install.log.new |while read a;do 
      P=$(echo $a|awk '{print $4}')
      R=$(egrep \
	    "$(echo $P|awk -f /usr/libexec/slackpkg/pkglist.awk | awk '{print " "$1" .* "$3" "$4"$"}'| sed -r 's/ [0-9]+([^\$]*)\$/ [0-9]+\1 /')" \
	    /var/lib/slackpkg/pkglist|awk '{print $1}'|sed 's/SLACKPKGPLUS_//'
	 )
      echo $a|sed "s/\[\]/[$R]/"
    done > $WORKDIR/install.log.tmp
    echo "An install log was created in $WORKDIR/install.log.tmp ; review it and rename in install.log"
  fi
else
  mv $WORKDIR/install.log.new $WORKDIR/install.log
  echo "An install log was created in $WORKDIR/install.log"
fi
