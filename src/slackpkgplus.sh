# vim: set tabstop=2 shiftwidth=2 expandtab 

# Thanks to AlienBob and phenixia2003 (on LQ) for contributing
# A special thanks to all packagers that make slackpkg+ useful

declare -A MIRRORPLUS
declare -A NOTIFYMSG

CONF=${CONF:-/etc/slackpkg} # needed if you're running slackpkg 2.28.0-12

  # regular expression used to distinguish the 3rd party repositories from the standard slackware directories.
  #
SLACKDIR_REGEXP="^((slackware)|(slackware64)|(extra)|(pasture)|(patches)|(testing))$"

  # CLOG_PKGREGEX : regular expression used to find package entry in ChangeLog files
  # CLOG_SEPREGEX : regular expression that match the "standard" entry separator in a ChangeLog file
CLOG_PKGREGEX="^[^ ]*:[ ]+(added|moved|rebuilt|upgraded)"
CLOG_SEPREGEX="^[+][-]+[+][ ]*$"

if [ -e $CONF/slackpkgplus.conf ];then
  # You can override GREYLIST WGETOPTS SLACKPKGPLUS VERBOSE USEBL ALLOW32BIT SENSITIVE_SEARCH from command-line
  EXTGREYLIST=$GREYLIST
  EXTALLOW32BIT=$ALLOW32BIT
  EXTSLACKPKGPLUS=$SLACKPKGPLUS
  EXTVERBOSE=$VERBOSE
  EXTUSEBL=$USEBL
  EXTWGETOPTS=$WGETOPTS
  EXTDOWNLOADCMD=$DOWNLOADCMD
  EXTTAG_PRIORITY=$TAG_PRIORITY
  EXTSENSITIVE_SEARCH=$SENSITIVE_SEARCH
  EXTCACHEUPDATE=$CACHEUPDATE
  EXTDOWNLOADONLY=$DOWNLOADONLY
  EXTSTRICTGPG=$STRICTGPG
  EXTDETAILED_INFO=$DETAILED_INFO
  EXTWW_FILE_SEARCH=$WW_FILE_SEARCH

  . $CONF/slackpkgplus.conf

  GREYLIST=${EXTGREYLIST:-$GREYLIST}
  ALLOW32BIT=${EXTALLOW32BIT:-$ALLOW32BIT}
  SLACKPKGPLUS=${EXTSLACKPKGPLUS:-$SLACKPKGPLUS}
  VERBOSE=${EXTVERBOSE:-$VERBOSE}
  USEBL=${EXTUSEBL:-$USEBL}
  WGETOPTS=${EXTWGETOPTS:-$WGETOPTS}
  DOWNLOADCMD=${EXTDOWNLOADCMD:-$DOWNLOADCMD}
  TAG_PRIORITY=${EXTTAG_PRIORITY:-$TAG_PRIORITY}
  SENSITIVE_SEARCH=${EXTSENSITIVE_SEARCH:-$SENSITIVE_SEARCH}
  CACHEUPDATE=${EXTCACHEUPDATE:-$CACHEUPDATE}
  DOWNLOADONLY=${EXTDOWNLOADONLY:-$DOWNLOADONLY}
  STRICTGPG=${EXTSTRICTGPG:-$STRICTGPG}
  DETAILED_INFO=${EXTDETAILED_INFO:-$DETAILED_INFO}
  WW_FILE_SEARCH=${EXTWW_FILE_SEARCH:-$WW_FILE_SEARCH}

  USEBLACKLIST=true
  if [ "$USEBL" == "0" ];then
    USEBLACKLIST=false
  fi
  if [ "$ENABLENOTIFY" = "on" -a -e $CONF/notifymsg.conf ];then
    . $CONF/notifymsg.conf
  fi
fi

if [ "$SLACKPKGPLUS" = "on" ];then


  # function internal_blacklist()
  # function applyblacklist()
  # function cleanup()
  # function handle_event()
  # function remove_pkg()
  # function installpkg() // if DOWNLOADONLY=on override /sbin/installpkg
  # function upgradepkg() // if DOWNLOADONLY=on override /sbin/upgradepkg
  # function upgrade_pkg()
  # function install_pkg()
  # function wgetdebug()
  # function cached_downloader()
  # function getfile()
  # function checkgpg()
  # function checkmd5()
  # function givepriority()
  # function searchPackages()
  # function searchlistEX()
  # function more_info()
  # function showChangeLogInfo()
  # function showlist() // dialog=on
  # function showlist() // dialog=off


  ##### ===== BLACKLIST FUNCTIONS === #####

    # Adds the pattern given by $(1) into the internal blacklist
    # ${TMPDIR}/blacklist.slackpkgplus
    #
    # ($1) The pattern to add.
    #
  function internal_blacklist() {
    echo "$1" >> ${TMPDIR}/blacklist.slackpkgplus
  } # END function internal_blacklist()

    # Override original applyblackist() so that internal blacklist will
    # be applied too.
    #
  function applyblacklist() {
    # -- This is to prevent silent exclusion of multilib package
    #    aaa_elflibs-compat32 when /etc/slackpkg/blacklist contains the
    #    pattern aaa_elflibs.
    if ! $USEBLACKLIST ;then
      >${TMPDIR}/blacklist
    fi
    if $MLREPO_SELELECTED && grep -q "^aaa_elflibs$" ${TMPDIR}/blacklist && ! grep -q "^aaa_elflibs-compat32$" ${TMPDIR}/blacklist ; then
      sed -i --expression "s/^aaa_elflibs/#aaa_elflibs/" ${TMPDIR}/blacklist
      grep -vEw -f ${TMPDIR}/blacklist -f ${TMPDIR}/blacklist.slackpkgplus | grep -v "[ ]aaa_elflibs[ ]" >${TMPDIR}/blacklist.tmp
    else
      grep -vEw -f ${TMPDIR}/blacklist -f ${TMPDIR}/blacklist.slackpkgplus >${TMPDIR}/blacklist.tmp
    fi
    if [ "$(head -1 ${TMPDIR}/blacklist.tmp|awk '{print $1}')" != "local" ];then
      cat ${TMPDIR}/pkglist-pre
    fi
    cat ${TMPDIR}/blacklist.tmp
    cat $TMPDIR/greylist.* >$TMPDIR/greylist
    grep -qvEw -f $TMPDIR/greylist $TMPDIR/pkglist-pre >$TMPDIR/unchecklist

  } # END function applyblacklist()

  ##### ====== END BLACKLIST FUNCTIONS === #####

  ##### ====== INSTALL/POSTINSTALL FUNCTIONS ====== #####

    # Override cleanup() to improve log messages and debug functions
    #
  function cleanup(){
    # Get the current exit-code so that we can check if cleanup is
    # called in response of a CTRL+C (ie. $?=130) or not.
    local lEcode=$?

    if [ "$CMD" == "info" ];then
      DETAILED_INFO=${DETAILED_INFO:-none}
      [[ "$DETAILED_INFO" != "none" ]]&&more_info
    fi
    rm -f ${TMPDIR}/waiting
    if [ "$CMD" == "update" ];then
      if [ "$ANSWER" != "Y" ] && [ "$ANSWER" != "y" ]; then
        touch $WORKDIR/pkglist
      fi

      # When cleanup() has not been called in response of a CTRL+C, copy
      # the files -downloaded and generated by getfile()- from
      # TMPDIR/ChangeLogs into WORKDIR/ChangeLogs
      #
      if [ $lEcode -ne 130 ] && [ -e ${TMPDIR}/ChangeLogs ] ; then
        if [ ! -e ${WORKDIR}/ChangeLogs ] ; then
          mkdir ${WORKDIR}/ChangeLogs
        else
          rm -f ${WORKDIR}/ChangeLogs/*
        fi
        cp ${TMPDIR}/ChangeLogs/* ${WORKDIR}/ChangeLogs
      fi
    fi
    [ "$TTYREDIRECTION" ] && exec 1>&3 2>&4
    [ "$SPINNING" = "off" ] || tput cnorm
    if [ "$DELALL" = "on" ] && [ "$NAMEPKG" != "" ]; then
      rm $CACHEPATH/$NAMEPKG &>/dev/null
    fi
    if [ $VERBOSE -gt 2 ];then
      echo "The temp directory $TMPDIR will NOT be removed!" >>$TMPDIR/info.log
      echo
    fi
    if [ -s $TMPDIR/error.log -o -s $TMPDIR/info.log ];then
      echo -e "\n\n=============================================================================="
    fi
    if [ -e $TMPDIR/error.log ]; then
      echo "  WARNING! One or more errors occurred while slackpkg was running"
      echo "------------------------------------------------------------------------------"
      cat $TMPDIR/error.log
      if [ -s $TMPDIR/info.log ];then
        echo "------------------------------------------------------------------------------"
      fi
    fi
    if [ -s $TMPDIR/info.log ]; then
      echo "  INFO! Debug informations"
      echo "------------------------------------------------------------------------------"
      cat $TMPDIR/info.log
      echo "=============================================================================="
    fi
    echo
    rm -f /var/lock/slackpkg.$$
    if [ $VERBOSE -lt 3 ];then
      rm -rf $TMPDIR
    fi
    exit
  } # END function cleanup()

    # -- handle the event $1 that occured on packages $SHOWLIST
    #
    # $1 the event that occurs, which can be install, upgrade, remove
    #
  function handle_event() {
    local EVENT="$1"
    local SELKEYS=""
    local KEY
    local PATLIST
    local EXPR
    local MSG
    local MSGLIST=""
    local USERKEY

    find $ROOT/var/log/packages/ -type f -printf "%f\n" | sort > ${TMPDIR}/installed.tmp

      # -- Get the basename of packages which have been effectively
      #    installed, upgraded, or removed

    if [ "$EVENT" == "remove" ] ; then
      echo "$SHOWLIST" | tr " " "\n"  | sort > ${TMPDIR}/showlist.tmp
      
      comm -1 ${TMPDIR}/installed.tmp ${TMPDIR}/showlist.tmp | rev | cut -f4- -d"-" | rev > ${TMPDIR}/basenames.tmp
    else
      echo "$SHOWLIST" | tr " " "\n" | rev | cut -f2- -d"." | rev | sort > ${TMPDIR}/showlist.tmp

      comm -1 -2 ${TMPDIR}/installed.tmp ${TMPDIR}/showlist.tmp | rev | cut -f4- -d"-" | rev > ${TMPDIR}/basenames.tmp
    fi

    SELKEYS=$(echo "${!NOTIFYMSG[@]}" | tr " " "\n" | grep "^on_${EVENT}@" | tr "\n" " ")

    for KEY in $SELKEYS ; do
      PATLIST="${KEY#*@}"
      EXPR=$(echo -en "$PATLIST" | \
                      tr --squeeze-repeats "," | \
                      sed -e "s/,$//" -e "s/^/(&/" -e "s/,/)|(/g" -e "s/$/&)/")

      NV_MATCHPKGS=$(grep -E "$EXPR" ${TMPDIR}/basenames.tmp | tr "\n" "," | sed -e "s/,$//")
      
      if [ ! -z "$NV_MATCHPKGS" ] ; then
        MSG=$(eval "echo \"${NOTIFYMSG[$KEY]}\"")
        [ -z "MSGLIST" ] && MSGLIST="$MSG\n" || MSGLIST="$MSGLIST\n$MSG"
      fi
    done

    if [ ! -z "$MSGLIST" ] ; then

      if [ "$DIALOG" = "on" ] || [ "$DIALOG" = "ON" ] ; then
        dialog --title "post-$EVENT notifications" --backtitle "slackpkg $VERSION" --msgbox "$MSGLIST" 12 70
      else
        MSGLIST="====[ POST-${EVENT} NOTIFICATIONS ]===================================== \n${MSGLIST}\n======================================================================="
        echo -e "\n$MSGLIST" | more
        echo -en "Hit a key to continue or wait 10 seconds\r"
        read -t 10 USERKEY
        echo "                                        "
      fi
    fi
  } # END function handle_event()

    # Overrides original remove_pkg(). Required by the notification mechanism.
  function remove_pkg() {
    local i

    for i in $SHOWLIST; do
      echo -e "\nPackage: $i"
      echo -e "\tRemoving... "
      removepkg $i
      if [ ! -e $ROOT/var/log/packages/$i ];then
        FDATE=$(ls -ltr --full-time $ROOT/var/log/removed_packages/$i|tail -1 |awk '{print $6" "$7}'|sed -r -e 's/\.[0-9]{9}//' -e 's,-,/,' -e 's,-,/,')
        echo "$FDATE removed:     $i" >> $WORKDIR/install.log
      fi
    done
    handle_event "remove"
  } # END function remove_pkg()

  if [ "$DOWNLOADONLY" == "on" ];then
    function installpkg() {
      echo "            Download only.. `basename $1` not installed!"
      DELALL=off
    } # END function installpkg()
    function upgradepkg() {
      echo "            Download only.. `basename $1` not upgraded!"
      DELALL=off
    } # END function upgradepkg()
  fi

    # Overrides original upgrade_pkg(). Required by the notification mechanism.
  function upgrade_pkg() {
    local i

    if [ "$DOWNLOAD_ALL" = "on" ]; then
      OLDDEL="$DELALL"
      DELALL="off"
      for i in $SHOWLIST; do
        getpkg $i true
      done
      DELALL="$OLDDEL"
    fi
    ls -1 $ROOT/var/log/packages > $TMPDIR/tmplist

    for i in $SHOWLIST; do
      PKGFOUND=$(grep -m1 -e "^$(echo $i|rev|cut -f4- -d-|rev)-[^-]\+-[^-]\+-[^-]\+$" $TMPDIR/tmplist)
      REPOPOS=$(grep -m1 " $(echo $i|sed 's/\.t.z//') "  $TMPDIR/pkglist|awk '{print $1}'|sed 's/SLACKPKGPLUS_//')
      getpkg $i upgradepkg Upgrading
      if [ -e "$ROOT/var/log/packages/$(echo $i|sed 's/\.t.z//')" ];then
        FDATE=$(ls -l --full-time $ROOT/var/log/packages/$(echo $i|sed 's/\.t.z//') |awk '{print $6" "$7}'|sed -r -e 's/\.[0-9]{9}//' -e 's,-,/,' -e 's,-,/,')
        echo "$FDATE upgraded:    $i  [$REPOPOS]  (was $PKGFOUND)" >> $WORKDIR/install.log
      fi
    done
    handle_event "upgrade"
  } # END function upgrade_pkg()

    # Overrides original install_pkg(). Required by the notification mechanism.
  function install_pkg() {
    local i

    if [ "$DOWNLOAD_ALL" = "on" ]; then
      OLDDEL="$DELALL"
      DELALL="off"
      for i in $SHOWLIST; do
        getpkg $i true
      done
      DELALL="$OLDDEL"
    fi
    for i in $SHOWLIST; do
      INSTALL_T='installed:  '
      if [ -e $ROOT/var/log/packages/$(echo $i|sed 's/\.t.z//') ];then
        INSTALL_T='reinstalled:'
      fi
      REPOPOS=$(grep -m1 " $(echo $i|sed 's/\.t.z//') "  $TMPDIR/pkglist|awk '{print $1}'|sed 's/SLACKPKGPLUS_//')
      getpkg $i installpkg Installing
      if [ -e "$ROOT/var/log/packages/$(echo $i|sed 's/\.t.z//')" ];then
        FDATE=$(ls -l --full-time $ROOT/var/log/packages/$(echo $i|sed 's/\.t.z//') |awk '{print $6" "$7}'|sed -r -e 's/\.[0-9]{9}//' -e 's,-,/,' -e 's,-,/,')
        echo "$FDATE $INSTALL_T $i  [$REPOPOS]" >> $WORKDIR/install.log
      fi
    done
    handle_event "install"
  } # END function install_pkg()

  ##### ====== END INSTALL/POSTINSTALL FUNCTIONS ====== #####


  ##### ====== DOWNLOADERS ====== ######

    # Implements an improved wget version for a verbose output
    #
  function wgetdebug(){
    local SRCURL
    local DSTFILE
    SRCURL=$2
    DSTFILE=$(echo $SRCURL|sed 's|/|,|g')
    if [ ${SRCURL:0:5} == "https" ];then
      WGETOPTSL="--no-check-certificate"
    fi
    if [ ${SRCURL:0:3} == "ftp" ];then
      WGETOPTSL="--passive-ftp"
    fi

    DOWNTIME=$(date +%s)

    wget $WGETOPTS $WGETOPTSL -O $TMPDIR/$DSTFILE $SRCURL 2>&1|tee $TMPDIR/$DSTFILE.log
    WGETERR=${PIPESTATUS[0]}
    cp $TMPDIR/$DSTFILE $1
    echo "exit code: $WGETERR" >>$TMPDIR/$DSTFILE.log
    DOWNTIME=$[$(date +%s)-$DOWNTIME]
    if [ $WGETERR -ne 0 ];then
      echo >> $TMPDIR/error.log
      echo "$SRCURL --> BAD" >> $TMPDIR/error.log
      echo "wget $WGETOPTS $WGETOPTSL -O $DSTFILE $SRCURL" >> $TMPDIR/error.log
      echo "exit code: $WGETERR" >> $TMPDIR/error.log
      echo "download time: $DOWNTIME secs" >> $TMPDIR/error.log
      echo "details:" >> $TMPDIR/error.log
      cat $TMPDIR/$DSTFILE.log >> $TMPDIR/error.log
      ls -l $DSTFILE >> $TMPDIR/error.log 2>&1
      md5sum $DSTFILE >> $TMPDIR/error.log 2>&1
      echo >> $TMPDIR/error.log
    else
      echo "$SRCURL --> OK" >> $TMPDIR/info.log
    fi
    return $WGETERR


  } # END function wgetdebug()


    # Implements CACHEUPDATE=on
    #
  function cached_downloader(){
    local SRCURL
    local CACHEFILE
    local SRCBASE
    local CURREPO
    SRCURL=$2
    SRCBASE=$(basename $SRCURL)
    CACHEFILE=$(echo $SRCURL|md5sum|awk '{print $1}')

    TOCACHE=0
    case $SRCBASE in
      CHECKSUMS.md5|CHECKSUMS.md5.asc|CHECKSUMS.md5.gz|CHECKSUMS.md5.gz.asc) TOCACHE=1 ; CURREPO=$(basename $1|sed -r -e "s/CHECKSUMS.md5-?//" -e "s/\.asc//" -e "s/\.gz//") ;;
      MANIFEST.bz2|PACKAGES.TXT) TOCACHE=1 ; CURREPO=$(basename $1|sed -e "s/-$SRCBASE//" -e "s/SLACKPKGPLUS_//");;
      ChangeLog.txt) TOCACHE=1 ; CURREPO=$(basename $1|sed -e "s/ChangeLog-//" -e "s/^-//" -e "s/\.txt//") ;;
      GPG-KEY) TOCACHE=0 ; CURREPO=${1/*gpgkey-tmp-/};;
      FILELIST.TXT) TOCACHE=1 ;;
    esac
    if [ -z "$CURREPO" ]; then
      CURREPO=slackware
    fi

    [ $SRCBASE != "ChangeLog.txt" ]||[ -z "$LEVEL" -o "$LEVEL" == "1" ]&&echo -n "    File: $CURREPO->$SRCBASE .."
    [ $VERBOSE -eq 3 ]&&echo -n " ($CACHEFILE) "
    if [ $TOCACHE -eq 1 ];then
      echo -n "." # ... -> tocache=1
      curl --max-time 10 --location --head $SRCURL 2>/dev/null|grep -v -e ^Date: -e ^Set-Cookie: -e ^Expires: -e ^X-Varnish:|sed 's///' > $TMPDIR/cache.head
      echo "Url: $SRCURL" >> $TMPDIR/cache.head
      #grep -q "200 OK" $TMPDIR/cache.head || echo "Header or Url Invalid!!! (`date`)"
      [ $VERBOSE -eq 3 ]&&(echo;cat $TMPDIR/cache.head|sed 's/^/  /')
      if grep -q "^HTTP/.* 404" $TMPDIR/cache.head;then
        if [ $SRCBASE == "ChangeLog.txt" ]&&[ $LEVEL -lt $LIMIT ];then
          echo -n
        else
          echo " Not Found."
        fi
        return 8 # wget return 8 if server return error so we return 8
      fi
      if [ -e $CACHEDIR/$CACHEFILE -a -e $CACHEDIR/$CACHEFILE.head ];then
        echo -n " ." # ... . -> is in cache
        [ $VERBOSE -eq 3 ]&&(echo;cat $CACHEDIR/$CACHEFILE.head|sed 's/^/  /')
        if diff $CACHEDIR/$CACHEFILE.head $TMPDIR/cache.head >/dev/null;then
          [ $VERBOSE -eq 3 ]&&echo "Cache valid!   If not please remove manually $CACHEDIR/$CACHEFILE !"
          echo " Cached." # ... . Cached.
          cp $CACHEDIR/$CACHEFILE $1
          return $?
        fi
        echo -n ". " # ... .. -> cache older or corrupted
        rm -f $CACHEDIR/$CACHEFILE $CACHEDIR/$CACHEFILE.head 2>/dev/null
      fi
      echo -n " Downloading... " # ... -> needed  # ... .. -> re-needed
      [ $VERBOSE -gt 1 ]&&echo
      $CACHEDOWNLOADER $1 $SRCURL
      ERR=$?
      echo
      if [ "$(ls -l $1 2>/dev/null|awk '{print $5}')" == "$(grep Content-Length: $TMPDIR/cache.head|awk '{print $2}')" ];then
        cp $1 $CACHEDIR/$CACHEFILE 2>/dev/null
        cp $TMPDIR/cache.head $CACHEDIR/$CACHEFILE.head 2>/dev/null
      fi
    else
      echo " Downloading..." # .. -> tocache=0
      $CACHEDOWNLOADER $1 $SRCURL
      ERR=$?
      echo
    fi
    return $ERR

  } # END function cached_downloader()

  ##### ====== END DOWNLOADERS ====== ######


  ##### ====== CORE FUNCTION ====== ######

    # Override the slackpkg getfile().
    # The new getfile() download all file needed from all defined repositories
    # then merge all in a format slackpkg-compatible
  function getfile(){
    local URLFILE
    URLFILE=$1

    if echo $1|egrep -q '/SLACKPKGPLUS_(file|dir|http|https|ftp)[0-9].*\.asc$';then
      return 0
    fi

    if [ ${URLFILE:0:1} = "/" ];then
      URLFILE="file:/$URLFILE"
    fi
    if echo $URLFILE|grep -q /SLACKPKGPLUS_;then
      PREPO=$(echo $URLFILE|sed -r 's#^.*/SLACKPKGPLUS_([^/]+)/.*$#\1#')
      URLFILE=$(echo $URLFILE|sed "s#^.*/SLACKPKGPLUS_$PREPO/#${MIRRORPLUS[$PREPO]}#")
    fi

    if echo $URLFILE | grep "^dir:/"|grep -q "/PACKAGES.TXT$";then
      touch $2
      return 0
    fi
    if echo $URLFILE | grep "^dir:/"|grep -q "/MANIFEST.bz2$";then
      echo -n|bzip2 -c >$2
      return 0
    fi

    URLFILE=$(echo $URLFILE|sed -e 's_^dir:/_file://_')

    if echo $URLFILE | grep -q "^file://" ; then
      URLFILE=${URLFILE:6}
      if [ -f $URLFILE ];then
        cp -v $URLFILE $2
      else
        return 1
      fi
    else
      $DOWNLOADER $2 $URLFILE
    fi
    if [ $? -ne 0 ];then
      if echo $2|grep -q SLACKPKGPLUS;then
        if [ "`basename $URLFILE`" != "MANIFEST.bz2" ];then
          echo -e "\n$URLFILE:\tdownload error" >> $TMPDIR/error.log
          if echo $2|grep -q .asc$;then
            echo "  Retry using 'slackpkg -checkgpg=off $CMD ...'" >> $TMPDIR/error.log
          fi
        else
          echo
          echo "                   !!! N O T I C E !!!"
          echo "    Repository '$PREPO' does not contains MANIFEST.bz2"
          echo "    Don't worry... it will work fine, but the command"
          echo "    'slackpkg file-search' will not work on that"
          echo "    repository"
          echo
          sleep 3
        fi
      fi
    fi

    if [ $(basename $1) = "MANIFEST.bz2" ];then
      rm -f $WORKDIR/*-filelist.gz 2>/dev/null
      if [ ! -s $2 ];then
        echo -n|bzip2 -c >$2
      fi
    fi

    if [ $(basename $1) = "CHECKSUMS.md5.asc" ];then
      if [ "$CHECKGPG" = "on" ];then
        for PREPO in ${REPOPLUS[*]};do
          URLFILE=${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}CHECKSUMS.md5.asc
          if echo $URLFILE | grep -q "^dir:/" ; then
            continue
          fi
          if echo $URLFILE | grep -q "^file://" ; then
            URLFILE=${URLFILE:6}
            cp -v $URLFILE ${TMPDIR}/CHECKSUMS.md5-$PREPO.asc
          else
            $DOWNLOADER ${TMPDIR}/CHECKSUMS.md5-$PREPO.asc $URLFILE
            if [ $? -ne 0 ];then
              $DOWNLOADER ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz.asc `echo $URLFILE|sed 's/\.asc$/.gz.asc/'`
              if [ $? -eq 0 ];then
                $DOWNLOADER ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz `echo $URLFILE|sed 's/\.asc$/.gz/'`
                if [ $(checkgpg ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz) -eq 1 ];then
                  echo
                  echo "                   !!! N O T I C E !!!"
                  echo "    Repository '$PREPO' does support signature checking for"
                  echo "    CHECKSUMS.md5 file, so the repository authenticity is guaranteed,"
                  echo "    but you MAY need to temporarily disable gpg check when you"
                  echo "    install the packages using:"
                  echo "    'slackpkg -checkgpg=off install packge'"
                  echo "    The package authenticity remains guaranteed."
                  echo
                  zcat ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz > ${TMPDIR}/CHECKSUMS.md5-$PREPO
                  sleep 5
                  continue
                fi
              fi
            fi
          fi
          if [ $? -eq 0 ];then
            if [ $(checkgpg ${TMPDIR}/CHECKSUMS.md5-$PREPO) -ne 1 ];then
              echo
              echo "                        !!! F A T A L !!!"
              echo "    Repository '$PREPO' FAILS the CHECKSUMS.md5 signature check"
              echo "    The file may be corrupted or the gpg key may be not valid."
              echo "    Remember to import keys by launching 'slackpkg update gpg'."
              echo
              sleep 5
              echo "Repository '$PREPO' FAILS the CHECKSUMS.md5 signature check." >> $TMPDIR/error.log
              echo "Try to run 'slackpkg update gpg'" >> $TMPDIR/error.log
              echo >> $TMPDIR/error.log
              echo > ${TMPDIR}/CHECKSUMS.md5-$PREPO
            fi
          else
            echo
            echo "                   !!! W A R N I N G !!!"
            echo "    Repository '$PREPO' does NOT support signature checking"
            echo "    You SHOULD disable GPG check by setting 'CHECKGPG=off'"
            echo "    in /etc/slackpkg/slackpkg.conf or use slackpkg with"
            echo "    '-checkgpg=off' : 'slackpkg -checkgpg=off install packge'"
            echo
            sleep 5
          fi
        done
      else
        checkgpg ${TMPDIR}/CHECKSUMS.md5 >/dev/null
      fi
    fi
    if [ $(basename $1) = "ChangeLog.txt" ];then

      # ChangeLog.txt from slackware and 3rd party repository are stored
      # into TMPDIR/ChangeLogs directory. This directory is automatically
      # moved into WORKDIR by function cleanup() unless when this function
      # is called in response to a CTRL+C
      #
      # see http://www.linuxquestions.org/questions/slackware-14/slackpkg-vs-third-party-package-repository-4175427364/page35.html#post5537830

      mkdir ${TMPDIR}/ChangeLogs

      # Copy slackware ChangeLog.txt into directory dedicated to changelogs...
      cat ${TMPDIR}/ChangeLog.txt > ${TMPDIR}/ChangeLogs/slackware.txt

      for PREPO in ${REPOPLUS[*]}; do
        BASEDIR=${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]%}
        CLOGNAM=$PREPO.txt

        if echo $BASEDIR | grep -q "^dir:/" ; then
          # dir:/ repositories are ignored by slackpkg update
          # but the ChangeLog must exists
          touch ${TMPDIR}/ChangeLogs/$CLOGNAM
          continue
        fi
        LIMIT=1

        if [ "$SEARCH_CLOG_INPARENT" == "on" ] ; then
          BDNAMES=( $(echo $BASEDIR | tr "/" " ") )
          LIMIT=$(( ${#BDNAMES[@]} - 1 ))
        fi


        LEVEL=1
        while [ ! -s ${TMPDIR}/$CLOGNAM ] && [ $LEVEL -le $LIMIT ] ; do

          URLFILE=${BASEDIR%/}/ChangeLog.txt

          if echo $URLFILE | grep -q "^file://" ; then
            URLFILE=${URLFILE:6}
            cp -v $URLFILE ${TMPDIR}/$CLOGNAM
          else
            if [ $VERBOSE -gt 2 ];then
              $DOWNLOADER ${TMPDIR}/$CLOGNAM $URLFILE
            else
              $DOWNLOADER ${TMPDIR}/$CLOGNAM $URLFILE 2>/dev/null
            fi
          fi

          ((LEVEL++))
          BASEDIR=$(echo ${BASEDIR%/} |rev|cut -f2- -d/ |rev)
        done

        if [ -s ${TMPDIR}/$CLOGNAM ] ; then
          echo -e "                Saving ChangeLog.txt from repository $PREPO ...\n"
          cat ${TMPDIR}/$CLOGNAM >> ${TMPDIR}/ChangeLogs/$CLOGNAM
        else
          echo -e "                Repository $PREPO has no ChangeLog.txt.\n"
          touch ${TMPDIR}/ChangeLogs/$CLOGNAM
        fi
      done

      # For each <reponame>.txt file in TMPDIR/ChangeLogs, create a corresponding
      # <reponame>.idx which is used by showChangeLogInfo()
      #
      # The output file is formatted as below :
      #   <idx>:<pathname>: <status>
      #
      # <idx> is the line index of the entry in original changelog <reponame>.txt
      # <pathname> is the full pathname of the package (ie. a/cryptsetup-1.7.1-x86_64-1.txz)
      # <status> is the package status, which can be added,moved,rebuilt,removed,upgraded)
      #
      for PREPO in slackware ${REPOPLUS[*]} ; do
        grep -inE "$CLOG_PKGREGEX" ${TMPDIR}/ChangeLogs/$PREPO.txt > ${TMPDIR}/ChangeLogs/$PREPO.idx
      done

      for PREPO in ${REPOPLUS[*]};do
        # Not all repositories have the ChangeLog.txt, so I use md5 of CHECKSUMS.md5 instead
        URLFILE=${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}CHECKSUMS.md5
        if echo $URLFILE | grep -q "^file://" ; then
          URLFILE=${URLFILE:6}
          cp -v $URLFILE ${TMPDIR}/CHECKSUMS.md5-$PREPO
        elif echo $URLFILE | grep -q "^dir:/" ; then
          touch ${TMPDIR}/CHECKSUMS.md5-$PREPO
          continue
        else
          $DOWNLOADER ${TMPDIR}/CHECKSUMS.md5-$PREPO ${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}CHECKSUMS.md5
        fi
        if [ ! -s ${TMPDIR}/CHECKSUMS.md5-$PREPO ];then
          echo
          echo "                        !!! F A T A L !!!"
          echo "    Repository '$PREPO' FAILS the CHECKSUMS.md5 download"
          echo "    The repository may be invalid and will be SKIPPED."
          echo
          sleep 5
          echo -e "$PREPO: SKIPPING Invalid repository (fails to download CHECKSUMS.md5)" >> $TMPDIR/error.log
          echo "    ( ${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}CHECKSUMS.md5 )" >> $TMPDIR/error.log

          PRIORITY=( $(echo ${PRIORITY[*]}" "|sed "s/SLACKPKGPLUS_$PREPO / /") )
          REPOPLUS=( $(echo " "${REPOPLUS[*]}" "|sed "s/ $PREPO / /") )
        else
          echo "SLACKPKGPLUS_$PREPO[MD5]" $(md5sum ${TMPDIR}/CHECKSUMS.md5-$PREPO|awk '{print $1}') >>$2
        fi

      done
    fi
    if [ $(basename $1) = "GPG-KEY" ];then
      mkdir -p ${WORKDIR}/gpg
      rm -f ${WORKDIR}/gpg/* 2>/dev/null
      gpg $2
      if gpg $2|grep -q "$SLACKKEY" || [ "$STRICTGPG" == "off" ];then
        for PREPO in $(echo ${PRIORITY[*]}|sed 's/SLACKPKGPLUS_[^ ]*//g');do
          gpg --output "${WORKDIR}/gpg/GPG-KEY-${PREPO}.gpg" --dearmor $2
        done
      else
        echo
        echo "                   !!! F A T A L !!!"
        echo "    Slackware repository does NOT contain the Official GPG-KEY"
        echo "    You SHOULD disable GPG Strict check 'STRICTGPG=off'"
        echo "    in /etc/slackpkg/slackpkgplus.conf"
        echo
        sleep 5
        echo "Fatal: Slackware repository does not contains the official gpg-key!!" >>$TMPDIR/error.log
        gpg $2 >>$TMPDIR/error.log 2>&1
      fi
      for PREPO in ${REPOPLUS[*]};do
        if [ "${PREPO:0:4}" = "dir:" ];then
          continue
        fi
        URLFILE=${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}GPG-KEY
        if echo $URLFILE | grep -q "^file://" ; then
          URLFILE=${URLFILE:6}
          cp -v $URLFILE $2-tmp-$PREPO
        elif echo $URLFILE |grep -q "^dir:/";then
          continue
        else
          echo
          $DOWNLOADER $2-tmp-$PREPO ${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}GPG-KEY
        fi
        if [ $? -eq 0 ];then
          gpg $2-tmp-$PREPO
          gpg --import $2-tmp-$PREPO
          gpg --output "${WORKDIR}/gpg/GPG-KEY-${PREPO}.gpg" --dearmor $2-tmp-$PREPO
        else
          echo
          echo "                   !!! W A R N I N G !!!"
          echo "    Repository '$PREPO' does NOT contain the GPG-KEY"
          echo "    You SHOULD disable GPG check by setting 'CHECKGPG=off'"
          echo "    in /etc/slackpkg/slackpkg.conf or use slackpkg with"
          echo "    '-checkgpg=off' : 'slackpkg -checkgpg=off install packge'"
          echo
          sleep 5
        fi
        rm $2-tmp-$PREPO
        echo
      done
    fi
  } # END function getfile()

    # override slackpkg checkgpg()
    # new checkgpg() is used to check gpg and to merge the CHECKSUMS.md5 files
  function checkgpg() {
    local FILENAME
    local REPO

    if echo $1|egrep -q "/SLACKPKGPLUS_(file|dir|http|ftp|https)[0-9]";then
      echo 1
      return
    fi
    if [ -e "${1}.asc" ];then

      FILENAME=$(basename ${1})
      if [ "$FILENAME" == "CHECKSUMS.md5" ];then
        REPO=slackware
        [ -e "${WORKDIR}/gpg/GPG-KEY-slackware64.gpg" ]&&REPO=slackware64
      elif [ ${FILENAME:0:13} == "CHECKSUMS.md5" ];then
        REPO=$(echo $FILENAME|cut -f2- -d-|sed 's/\.gz$//')
      else
        REPO=$(echo $1|sed -r -e "s,^$TEMP,/," -e "s,/\./,/,g" -e "s,//,/,g" -e "s,^/,," -e "s,/.*$,," -e "s,SLACKPKGPLUS_,,")
      fi

      if [ "$STRICTGPG" != "off" ] && ! echo ${MIRRORPLUS[$REPO]}|grep -q ^dir:/;then
        if [ ! -z "$REPO" ] && [ -e "${WORKDIR}/gpg/GPG-KEY-${REPO}.gpg" ] ; then
          gpg  --no-default-keyring \
               --keyring ${WORKDIR}/gpg/GPG-KEY-${REPO}.gpg \
               --verify ${1}.asc ${1} 2>/dev/null && echo "1" || echo "0"
        else
          echo "No matching GPG-KEY for repository '$REPO' checking $FILENAME" >&2
          echo "Try to run 'slackpkg update gpg' or 'slackpkg -checkgpg=off $CMD ...'" >&2
          echo "No matching GPG-KEY for repository '$REPO' checking $FILENAME" >>$TMPDIR/error.log
          echo "Try to run 'slackpkg update gpg' or 'slackpkg -checkgpg=off $CMD ...'" >>$TMPDIR/error.log
          echo 0
        fi
      else
        gpg --verify ${1}.asc ${1} 2>/dev/null && echo "1" || echo "0"
      fi
    else # $1.asc not downloaded
      echo 1
    fi
    if [ "$(basename $1)" == "CHECKSUMS.md5" ];then
      if [ "$TAG_PRIORITY" == "on" ];then
        mv ${TMPDIR}/CHECKSUMS.md5 ${TMPDIR}/CHECKSUMS.md5-old
        for PREPO in ${PRIORITY[*]};do
          grep " \./$PREPO/" ${TMPDIR}/CHECKSUMS.md5-old >> ${TMPDIR}/CHECKSUMS.md5
        done
      fi
      X86_64=$(ls $ROOT/var/log/packages/aaa_base*x86_64* 2>/dev/null|head -1)
      for PREPO in ${REPOPLUS[*]};do
        if [ -z "$X86_64" ];then
          FILTEREXCLUDE="-(x86_64|arm)-"
        elif [ "$ALLOW32BIT" == "on" ];then
          FILTEREXCLUDE="-(arm)-"
        else
          FILTEREXCLUDE="-(x86|i[3456]86|arm)-"
        fi
        egrep -e ^[a-f0-9]{32} ${TMPDIR}/CHECKSUMS.md5-$PREPO|egrep -v -- "$FILTEREXCLUDE" |sed -r -e "s# \./# ./SLACKPKGPLUS_$PREPO/#" >> ${TMPDIR}/CHECKSUMS.md5
        #egrep -e ^[a-f0-9]{32} ${TMPDIR}/CHECKSUMS.md5-$PREPO|egrep -v -- "$FILTEREXCLUDE" |sed -r -e "s# \./# ./SLACKPKGPLUS_$PREPO/#" -e 's#^(.*)/([^/]+)$#\2 \1/\2#'|sort -rn|cut -f2- -d" " >> ${TMPDIR}/CHECKSUMS.md5
      done
    fi
  } # END function checkgpg()

    # override slackpkg checkmd5()
    # Verify if the package was corrupted by checking md5sum
  function checkmd5() {
    local MD5ORIGINAL
    local MD5DOWNLOAD
    local PREPO
    local ARG

    if echo $1|egrep -q "/SLACKPKGPLUS_(file|dir|http|ftp|https)[0-9]";then
      echo 1
      return
    fi
    ARG=$(echo $1|sed "s|^$TEMP/||")
    PREPO=$(echo $ARG | cut -f2 -d/|sed 's/SLACKPKGPLUS_//' )
    if echo ${MIRRORPLUS[$PREPO]}|grep -q ^dir:/;then
      echo 1
      return
    fi

    MD5ORIGINAL=$( grep -m1 "$ARG$" ${CHECKSUMSFILE} | cut -f1 -d \ )
    MD5DOWNLOAD=$(md5sum ${1} | cut -f1 -d \ )
    if [ "$MD5ORIGINAL" = "$MD5DOWNLOAD" ]; then
      echo 1
    else
      echo 0
    fi
  } # END function checkmd5()

  #### ====== END CORE FUNCTIONS ======= ####


  #### ===== PRIORITY AND SEARCH FUNCTIONS ===== #####

    # Found packages in repository.
    # This function selects the package from the higher priority
    # repository directories.
    #
    # This Modified version supports enhanced priority rule (priority
    # given to package(s) from a given repository). This kind of priority
    # uses the following syntax :
    #
    #   repository_name:pattern
    #
  function givepriority() {
    local DIR
    local ARGUMENT=$1
    local PKGDATA
    local CPRIORITY
    local DIR
    local PKG

    unset NAME
    unset FULLNAME
    unset PKGDATA
    unset LINEIDX
    unset PKGINFOS

    AUTOP=no
    if [[ "$CMD" == "upgrade" || "$CMD" == "upgrade-all" ]];then
      ( cd $ROOT/var/log/packages
        ls $ARGUMENT-*-*-* 2>/dev/null|sed 's/$/.txz/' | awk -f /usr/libexec/slackpkg/pkglist.awk|grep -q " $ARGUMENT "
      )||return
      if [ ! -z "$AUTOPRIORITY" ];then
        if echo "$ARGUMENT"|grep -wq $AUTOPRIORITY;then
          AUTOP=$TAG_PRIORITY
        fi
      fi
      if [ "$CMD" == "upgrade-all" ];then
        AUTOP=$TAG_PRIORITY
      fi
    fi
    if [[ "$CMD" == "reinstall" ]];then
      PKGINFOS=$( grep " $ARGUMENT " $TMPDIR/tmplist|awk '{print " "$6" "}'|grep -f - -n ${TMPDIR}/pkglist|grep -f ${TMPDIR}/priority.filters -E -m 1 )
    fi
    if [ "$AUTOP" == "on" ] ; then
      PKGINFOS=$(
                  cd $ROOT/var/log/packages
                  ls $ARGUMENT-* 2>/dev/null |sed 's/$/.txz/' | awk -f /usr/libexec/slackpkg/pkglist.awk|
                                              grep " $ARGUMENT "|awk '{print $1,$4}'|
                                              ( read X && (
                                                echo "$X"|sed -r -e 's/ [0-9]+([^0-9].*)*$/ [^ ]\\+ [^ ]\\+ [0-9]\\+\1 /' -e 's/^/ /'
                                                echo "$X"|sed -r -e 's/ [0-9]+([^0-9].*)*$/ [^ ]\\+ [^ ]\\+ [0-9]\\+\1_slack[0-9]/' -e 's/^/ /'
                                                )
                                              )| grep -f - -n -m 1 ${TMPDIR}/pkglist
                )
    fi
    if [ ! -z "$PKGINFOS" ] ; then
      LINEIDX=${PKGINFOS/:*/}
      PKGDATA=( ${PKGINFOS/*:/} )
      if [ ${PRIORITYIDX} -ne ${LINEIDX} ];then
        mv ${TMPDIR}/pkglist ${TMPDIR}/pkglist.old
        sed --expression "${LINEIDX}d" --expression "${PRIORITYIDX}i${PKGDATA[*]}" ${TMPDIR}/pkglist.old > ${TMPDIR}/pkglist
      fi
      (( PRIORITYIDX++ ))
      if [ "$PKGDATA" ]; then
        NAME=${PKGDATA[1]}
        FULLNAME=$(echo "${PKGDATA[5]}.${PKGDATA[7]}")
      fi
    fi

    for CPRIORITY in ${PRIORITY[@]} ; do
      [ "$PKGDATA" ] && break

      DIR=${CPRIORITY/:*/}
      [[ "$CPRIORITY" =~ .*:.* ]] && PAT=${CPRIORITY/*:/} || PAT=""
      PAT=${PAT/.t?z/}
      REPOSITORY=${DIR/SLACKPKGPLUS_/}

        # pass to the next iteration when there are priority filters and the
        # current repository is not accepted by the defined filter rules ...
      if [ -s ${TMPDIR}/priority.filters ] \
        && ! grep -q -E "^([.][*]|${REPOSITORY}) " ${TMPDIR}/priority.filters ; then
        continue
      fi

      if [[ "$CPRIORITY" =~ ^[-_[:alnum:]]+[:] ]] ; then

          # [Reminder] ARGUMENT is always a basename, but PAT can be :
          #    1. a basename (ie. gcc, glibc-solibs)
          #    2. a regular expression (ie. .*)
          #    3. a (in)complete package name (ie. vlc-2, vlc-2.0.6, 1.0.3)
          #
        PKGDATA=""
        LINEIDX=""
        PKGINFOS=$(grep -n "^${DIR} " ${TMPDIR}/pkglist | grep 2>/dev/null -w "${PAT}" | grep -m 1 "^[[:digit:]]\+:${DIR} ${ARGUMENT} ")

        if [ ! -z "$PKGINFOS" ] ; then
          LINEIDX=${PKGINFOS/:*/}
          PKGDATA=( ${PKGINFOS/*:/} )
        fi
      elif [[ "$CPRIORITY" =~ ^[.][*][:] ]] ; then
        PKGDATA=""
        LINEIDX=""
        PKGINFOS=$(grep 2>/dev/null -n -w "${PAT}" ${TMPDIR}/pkglist | grep -m 1 " ${ARGUMENT} ")

        if [ ! -z "$PKGINFOS" ] ; then
          LINEIDX=${PKGINFOS/:*/}
          PKGDATA=( ${PKGINFOS/*:/} )
        fi
      else
          # $CPRIORITY is of kind "repository" (ie. slackware, extra, patches,...)
        REPOSITORY="${CPRIORITY}"
        PKGDATA=( $(grep -n -m 1 "^${REPOSITORY} ${ARGUMENT} " ${TMPDIR}/pkglist) )
      fi


      if [ "$PKGDATA" ]; then
        NAME=${PKGDATA[1]}
        FULLNAME=$(echo "${PKGDATA[5]}.${PKGDATA[7]}")

        if [ -s ${TMPDIR}/priority.filters ] ; then
            # there are priority filters set. Ensure the current selected
            # package is accepted by the defined filter rules. Otherwise,
            # reset PKGDATA and LINEIDX
            #

            # extract patterns from prioriy.filters whose 1st FIELD match ${REPOSITORY},
            # and, if there are filter of type .*:P, add their patterns too ...
          grep "^${REPOSITORY} " ${TMPDIR}/priority.filters | cut -f2 -d" " > ${TMPDIR}/filter.patterns
          grep "^[.][*] " ${TMPDIR}/priority.filters | cut -f2 -d" " >> ${TMPDIR}/filter.patterns

            # If no filter patterns were found, or if the selected package does not
            # match any of the filter patterns, the selected package is rejected...
          if [ ! -s ${TMPDIR}/filter.patterns ] || ! echo "${PKGDATA[5]}.${PKGDATA[7]}" | grep -q -f ${TMPDIR}/filter.patterns ;  then
            PKGDATA=""
            LINEIDX=""
            NAME=""
            FULLNAME=""
          fi
        fi
      fi

      if [ ! -z "$LINEIDX" ] ; then
          # CPRIORITY is of kind reponame:pattern or .*:pattern. The selected package is at line #LINEIDX. To
          # ensure that slackpkg (ie. core code) will install|upgrade this (exact) package, the
          # line which describes it (ie. in TMPDIR/pkglist) must be moved at line #PRIORITYIDX.
          #
          # Without this move, slackpkg could install|upgrade the wrong package. For instance,
          # if there are 2 repositories R1 and R2 which have two differents version of the
          # same package (ie. built with different options) but which have the same name P, if
          # R1:P is before R2:P in pkglist, and the user issue install|upgrade R2:P, slackpkg
          # will install R1:P instead.
          #
        if [ ${PRIORITYIDX} -ne ${LINEIDX} ];then
          mv ${TMPDIR}/pkglist ${TMPDIR}/pkglist.old
          sed  --expression "${LINEIDX}d" --expression "${PRIORITYIDX}i${PKGDATA[*]}" ${TMPDIR}/pkglist.old > ${TMPDIR}/pkglist
        fi
        (( PRIORITYIDX++ ))
      fi
    done
  } # END function givepriority()

    # Improved 'slackpkg search'/'slackpkg file-search'
    #
  function searchPackages() {
    local i
    local GREPOPTS=""

    SEARCHSTR=$@

    grep -vE "(^#|^[[:blank:]]*$)" ${CONF}/blacklist > ${TMPDIR}/blacklist
    if echo $CMD | grep -q install ; then
      ( cd $ROOT/ ; ls -1 ./var/log/packages/* ) | awk -f /usr/libexec/slackpkg/pkglist.awk > ${TMPDIR}/tmplist
    else
      ( cd $ROOT/ ; ls -1 ./var/log/packages/* ) | awk -f /usr/libexec/slackpkg/pkglist.awk | applyblacklist > ${TMPDIR}/tmplist
    fi
    cat ${WORKDIR}/pkglist | applyblacklist > ${TMPDIR}/pkglist

    touch ${TMPDIR}/waiting
    echo -n "Looking for $PATTERN in package list. Please wait... "
    [ "$SPINNING" = "off" ] || spinning ${TMPDIR}/waiting &

    [ "$SENSITIVE_SEARCH" = "off" ] && GREPOPTS="--ignore-case"

    # -- PKGLIST:
    #      temporary file used to store data about packages. It uses
    #      the following format:
    #        repo:<repository_name>:bname:<package_basename>:ver:<package_version>:fname:<package_fullname>:
    #
    PKGLIST=$(tempfile --directory=$TMPDIR)
    PKGINFOS=$(tempfile --directory=$TMPDIR)

    for i in ${PRIORITY[@]}; do
      DIR="$i"
      if [[ "$DIR" =~ ^[-_[:alnum:]]+[:] ]] ; then   # was  if echo "$DIR" | grep -q "[a-zA-Z0-9]\+[:]" ; then
        DIR=${DIR/:*/}                               # was DIR=$(echo "$i" | cut -f1 -d":")
      fi

      if [ "$CMD" == "file-search" ] ; then
        [ ! -e "${WORKDIR}/${DIR}-filelist.gz" ] && continue
        [ ! "$WW_FILE_SEARCH" = "off" ] && GREPOPTS="$GREPOPTS --word-regexp"

        # NOTE:
        #  The awk below produces an output formatted like
        #  in file TMPDIR/pkglist, but without true values
        #  for the fields: version(3) arch(4) build(5), path(7),
        #  extension(8)
        #
        zegrep ${GREPOPTS} "${SEARCHSTR}" ${WORKDIR}/${DIR}-filelist.gz | \
          cut -d" " -f 1 | rev | cut -f2- -d"." | cut -f1 -d"/" | rev |\
          awk '{
                  l_pname=$0
                  l_count=split($0,l_parts,"-");
                  l_basename=l_parts[1];
                  for (i=2;i<=l_count-3;i++) {
                          l_basename=l_basename"-"l_parts[i];
                  }
                  print l_dir" "l_basename" ------- ---- ----- "l_pname" ---- ---------"
          }' l_dir=${DIR} > $PKGINFOS

      else # -- CMD==search
        grep -h ${GREPOPTS} "^$DIR" ${WORKDIR}/pkglist ${TMPDIR}/pkglist-pre|grep -E ${GREPOPTS} "/SLACKPKGPLUS_$SEARCHSTR/|/$SEARCHSTR/|/$SEARCHSTR | [^ /]*$SEARCHSTR[^ /]* " > $PKGINFOS
      fi

      while read PKGDIR PKGBASENAME PKGVER PKGARCH PKGBUILD PKGFULLNAME PKGPATH PKGEXT ; do

        # does nothing when the package has been handled ...
        grep ${GREPOPTS} -q "^repo:${PKGDIR}:bname:${PKGBASENAME}:ver:${PKGVER}:fname:${PKGFULLNAME}:" $PKGLIST && continue

        # When a package P' with the same basename has been handled before the current package, this means
        # the package P' has precedence over P.

        if grep ${GREPOPTS} -q ":bname:${PKGBASENAME}:" $PKGLIST ; then

           # if the current package P is installed, this means the previous P' will be
           # proposed as an upgrade to P. In this case, the loop must continue without
           # any other action...
          grep ${GREPOPTS} -q " $PKGFULLNAME " ${TMPDIR}/tmplist && continue

            # The current package P is not installed. In this case P must be shown as
            # being uninstalled and masked.
          LIST="$LIST MASKED_${PKGDIR}:${PKGFULLNAME}"
        else
          LIST="$LIST ${PKGDIR}:${PKGFULLNAME}"
        fi

        echo "repo:${PKGDIR}:bname:${PKGBASENAME}:ver:${PKGVER}:fname:${PKGFULLNAME}:" >> $PKGLIST

      done < $PKGINFOS
    done
    rm ${TMPDIR}/waiting
    rm -f $PKGLIST $PKGINFOS

    LIST=$(echo -e $LIST | tr \  "\n" | uniq )

    echo -e "DONE\n"
  } # END function searchPackages()

  #### ===== PRIORITY AND SEARCH FUNCTIONS ===== #####

  #### ===== SHOWLIST FUNCTIONS ====== ######

    # generate output for 'slackpkg search'/'slackpkg file-search'
    #
  function searchlistEX() {
    local i
    local BASENAME
    local RAWNAME
    local STATUS
    local INSTPKG
    local REPO
    local PNAME

    printf "[ %-16s ] [ %-24s ] [ %-40s ]\n" "Status" "Repository" "Package"

    INSTPKGS="$(ls -f $ROOT/var/log/packages)"

    for i in $1; do
      REPO=${i/:*/} #$(echo "$i" | cut -f1 -d":")
      PNAME=${i/*:/} #PNAME=$(echo "$i" | cut -f2- -d":")

      REPO=${REPO/SLACKPKGPLUS_/}     #REPO=$(echo "$REPO" | cut -f2- -d"_")

      # BASENAME is base package name
      BASENAME=${PNAME%-*-*-*}        #BASENAME="$(cutpkg ${PNAME})"

      # RAWNAME is Latest available version
      RAWNAME="${PNAME/%.t[blxg]z/}"

      # Default is uninstalled
      STATUS="uninstalled"

      if [[ $REPO =~ ^MASKED_.* ]] ; then
        REPO=${REPO/MASKED_/}
        STATUS="uninstalled(masked)"
        INSTPKG=""
      else
        # First is the package already installed?
        # Amazing what a little sleep will do
        # exclusion is so much nicer :)
        INSTPKG=$(echo "$INSTPKGS"|grep "^${BASENAME}-[^-]\+-[^-]\+-[^-]\+$")
      fi


      # INSTPKG is local version
      if [ ! "${INSTPKG}" = "" ]; then

        # INSTPKG can contains more than one package. But only those
        # that match the basename ${BASENAME} must be handled

        for CINSTPKG in ${INSTPKG} ; do
          CBASENAME=${CINSTPKG%-*-*-*}

          if [ "${CBASENAME}" == "${BASENAME}" ] ; then

            # If installed is it uptodate?
            if [ "${CINSTPKG}" = "${RAWNAME}" ]; then
              STATUS=" installed "
              printf "  %-20s     %-24s     %-40s  \n" "$STATUS" "$REPO" "$CINSTPKG"
            else
              STATUS="upgrade"
              printf "  %-20s     %-24s     %-40s  \n" "$STATUS" "$REPO" "$CINSTPKG --> ${RAWNAME}"
            fi
          fi
        done
      else
        printf "  %-20s     %-24s     %-40s  \n" "$STATUS" "$REPO" "${RAWNAME}"
      fi
    done|sort|( [[  "$CMD" == "search" ]]&&grep -E -i --color -e ^ -e "$PATTERN"||cat )
  } # END function searchlistEX()

    # Show detailed info for slackpkg info
    #
  function more_info(){
    echo
    cat $WORKDIR/pkglist|grep -E "^[^ ]* $NAME "|while read repository name version arch tag namepkg fullpath ext;do
      echo "Package:    $namepkg"
      echo "Repository: ${repository/SLACKPKGPLUS_/}"
      echo "Path:       ${fullpath/\/SLACKPKGPLUS_${repository/SLACKPKGPLUS_/}/}/$namepkg.$ext"
      URLFILE=${SOURCE}${fullpath}/${namepkg}.${ext}
      if echo $URLFILE|grep -q /SLACKPKGPLUS_;then
        PREPO=$(echo $URLFILE|sed -r 's#^.*/SLACKPKGPLUS_([^/]+)/.*$#\1#')
        URLFILE=$(echo $URLFILE|sed "s#^.*/SLACKPKGPLUS_$PREPO/#${MIRRORPLUS[$PREPO]}#")
      fi
      echo "Url:        ${URLFILE/.\//}"
      if [ "$DETAILED_INFO" == "filelist" ];then
        FILELIST="$(zgrep ^${fullpath/\/${repository}/}/$namepkg.$ext $WORKDIR/$repository-filelist.gz 2>/dev/null)"
        if [ -z "$FILELIST" ];then
          echo "Filelist:   no file list available"
        else
          echo "Filelist:"
          echo "$FILELIST"|sed "s/ /\n/g"|tail +2|sed 's/^/  /'
        fi
      fi
      echo
    done
  } # END function more_info()

  if [ "$DIALOG" = "on" ] || [ "$DIALOG" = "ON" ]; then
    # Slackpkg+ Dialog functions
    # Original functions from slackpkg modified by Marek Wodzinski (majek@mamy.to)
    #
    export DIALOG_CANCEL="1"
    export DIALOG_ERROR="126"
    export DIALOG_ESC="1"
    export DIALOG_EXTRA="3"
    export DIALOG_HELP="2"
    export DIALOG_ITEM_HELP="2"
    export DIALOG_OK="0"

      # Prints, into a dialog box, the changelog entries about the packages listed in file $1
      #
    function showChangeLogInfo() {
      local Cpkg
      local CpkgInfos
      local CLogIdxFile
      local CLogStartIdx
      local Pathname
      local Status
      local Cline
      local Repository

      echo -n "" > $TMPDIR/Packages.clog

      for Cpkg in $(<$TMPDIR/dialog.out) ; do

        #  get infos about the current package from *.idx files in WORKDIR/ChangeLogs, 
        #  if any. The  variable CpkgInfos is a string formatted as below:
        #    path/<reponame>.idx:<clogidx>:<pathname>:<status>
        #
        #  clogidx=line index of the entry in WORKDIR/ChangeLogs/<reponame>.txt that match Cpkg
        #
        CpkgInfos=( $(grep -R $Cpkg  $WORKDIR/ChangeLogs/*.idx | tr ":" " ") )

        if [ ! -z "$CpkgInfos" ] ; then
          CLogIdxFile=${CpkgInfos[0]}
          CLogStartIdx=${CpkgInfos[1]}
          Pathname=${CpkgInfos[2]}
          Status=$(echo ${CpkgInfos[3]} | tr --delete " .")

          # Get the repository name containing a changelog entry about the current 
          # package (ie Cpkg). 
          #
          Repository=$(basename $CLogIdxFile .idx)

          echo "$Repository::$Pathname ($Status)" >> $TMPDIR/Packages.clog

          # extra information on package Cpkg can be found in file
          # WORKDIR/ChangeLogs/${Repository}.txt starting at line 
          # CLogStartIdx+1 and ending the line before the first line matching 
          # the regular expression CLOG_SEPREGEX or CLOG_PKGREGEX.
          #
          # CLOG_SEPREGEX match the "standard" changelog separator entry, ie. a string
          # which start with a plus followed by dashes and a plus. For instance:
          #  +----------------------+
          #
          # CLOG_PKGREGEX match the "standard" changelog package entry, ie. a string
          # which starts with a package pathname followed by colon, one or more
          # space and the status. For instance:
          #   n/bind-1.2.3-x86_64-1.txz: Upgraded.

          ((CLogStartIdx++))

          tail -n "+$CLogStartIdx" $WORKDIR/ChangeLogs/${Repository}.txt | while read Cline ; do
            if ! echo "$Cline" | grep -qiE "($CLOG_SEPREGEX)|($CLOG_PKGREGEX)" ; then
              echo -e "    $Cline" >> $TMPDIR/Packages.clog
            else
              break
            fi
          done
          echo "" >> $TMPDIR/Packages.clog
        fi
      done

      if [ ! -s $TMPDIR/Packages.clog ] ; then
        echo "Sorry, no entry in the ChangeLog.txt matching the selected packages." > $TMPDIR/Packages.clog
      fi

      dialog --title "ChangeLog" \
        --backtitle "slackpkg $VERSION" $HINT \
        --textbox $TMPDIR/Packages.clog 19 70
    } # END function showChangeLogInfo()


    # Show the lists and asks if the user want to proceed with that action
    # Return accepted list in $SHOWLIST
    #
    function showlist() {
      local CLOGopt=false
      local EXIT=false

      if [ "$ONOFF" != "off" ]; then
        ONOFF=on
      fi

      if [ "$2" == "upgrade" ] || [ "$2" == "upgrade-all" ] || [ "$2" == "install" ] ; then
        CLOGopt=true
      fi

      cat $TMPDIR/greylist.* >$TMPDIR/greylist
      if [ "$GREYLIST" == "off" ];then
        >$TMPDIR/greylist
      fi
      rm -f $TMPDIR/dialog.tmp
      
      if [ "$2" = "upgrade" ]; then
        ls -1 $ROOT/var/log/packages > $TMPDIR/tmplist
        for i in $1; do
          TMPONOFF=$ONOFF
          BASENAME=$(cutpkg $i)
          PKGFOUND=$(grep -m1 -e "^${BASENAME}-[^-]\+-[^-]\+-[^-]\+$" $TMPDIR/tmplist)
          REPOPOS=$(grep -m1 " $(echo $i|sed 's/\.t.z//') "  $TMPDIR/pkglist|awk '{print $1}'|sed 's/SLACKPKGPLUS_//')
          REPOPOSFULL=$(grep -m1 " $(echo $i|sed 's/\.t.z//') "  $TMPDIR/pkglist|sed 's/SLACKPKGPLUS_//'|awk '{print $0,gensub(/([0-9]+)([^0-9]*)/,"\\1 \\2_","1",$5),$6}')
          PKGVER=$(echo $i|rev|cut -f3 -d-|rev)
          ALLFOUND=$(echo $(grep " ${BASENAME} " $TMPDIR/pkglist|sed -r -e 's/SLACKPKGPLUS_//' -e 's/^([^ ]*) [^ ]* ([^ ]*) [^ ]* ([^ ]*) .*/\2-\3(\1) ,/')|sed 's/,$//')

          ( echo $PKGFOUND ; grep -m1 " ${BASENAME} " $TMPDIR/pkglist ) |grep -q -Ew -f $TMPDIR/greylist && TMPONOFF="off"
          echo "$REPOPOSFULL $i \"$REPOPOS\" $TMPONOFF \"installed: $PKGFOUND  -->  available: $ALLFOUND\"" >>$TMPDIR/dialog.tmp.1
        done

        # 1    2       3      4    5 6                     7         8   9 1011                    12-
        # repo package 1.0.12 i586 1 package-1.0.12-i586-1 ./path/to txz 1 _ package-1.0.12-i586-1 package-1.0.12-i586-1.txz "repo" on "installed: ... "
        case "$SHOWORDER" in
          "repository") SHOWORDER=1;;
          "arch")       SHOWORDER=4;;
          "package")    SHOWORDER=6;;
          "path")       SHOWORDER=7;;
          "tag")        SHOWORDER=10;;
          *)            SHOWORDER=6;;
        esac
        cat $TMPDIR/dialog.tmp.1 | awk '{print $'$SHOWORDER',$0}'|sort|cut -f13- -d" " >$TMPDIR/dialog.tmp
        HINT="--item-help"

      else # other than 'upgrade'

        for i in $1; do
          TMPONOFF=$ONOFF
          REPOPOS=$(grep -m1 " $(echo $i|sed 's/\.t.z//') "  $TMPDIR/pkglist|awk '{print $1}'|sed 's/SLACKPKGPLUS_//')
          ( echo $i;grep -m1 " $(echo $i|sed 's/\.t.z//') "  $TMPDIR/pkglist ) | grep -q -Ew -f $TMPDIR/greylist && TMPONOFF="off"
          echo "$i \"$REPOPOS\" $TMPONOFF" >>$TMPDIR/dialog.tmp
        done
        HINT=""
      fi

      # This is needed because dialog have a limit of arguments.
      # This limit is around 20k characters in slackware 10.x
      # Empiric tests on slackware 13.0 got a limit around 139k.
      # If we exceed this limit, dialog got a terrible error, to
      # avoid that, if the number of arguments is bigger than
      # DIALOG_MAXARGS we remove the hints. If even without hints
      # we can't got less characters than DIALOG_MAXARGS we give an
      # error message to the user ask him to not use dialog
      if [ $(wc -c $TMPDIR/dialog.tmp | cut -f1 -d\ ) -ge $DIALOG_MAXARGS ]; then
        mv $TMPDIR/dialog.tmp $TMPDIR/dialog2.tmp
        awk '{ NF=3 ; print $0 }' $TMPDIR/dialog2.tmp > $TMPDIR/dialog.tmp
        HINT=""
      fi
      DTITLE=$2
      if [ "$DOWNLOADONLY" == "on" ];then
        DTITLE="$DTITLE (download only)"
      fi

      if $CLOGopt ; then
        # When the user "click" the button <ChangeLog> to read the changelog of
        # the selected pacakges, the
        # duplicate TMPDIR/dialog.tmp so that all items are deselected to be able to
        # regenerate the list of selected items when showChangeLogInfo() returns, ie.
        # when the user has checked the changelog.

        # When the user "clicks" the button "<ChangeLog>" to read the changelog of
        # currently selected packages,  the dialog to select packages is terminated
        # and the changelog is printed in a textbox.
        #
        # When the user exits from the textbox, the user must retrieve the packages
        # selection dialog with the packages that were selected previously. To do that,
        # the file $TMPDIR/dialog.tmp is duplicated with all items deselected into
        # file $TMPDIR/dialog.tmp.off, so that the list of selected packages can
        # be regenerated using the data in file $TMPDIR/dialog.out when
        # showChangeLogInfos() returns.

          # in case of install, dialog.tmp is to the format (1), otherwise the format (2)
          # is used :
          #
          # format (1)
          #   <pkg-name> <repository> on|off
          # format (2)
          #   <pkg-name> <repository> on|off <installed-version> --> <available-version>

        if [ "$2" == "install" ] ; then
                cat $TMPDIR/dialog.tmp | sed "s/ on$/ off/g" > $TMPDIR/dialog.tmp.off
        else
                cat $TMPDIR/dialog.tmp | sed "s/ on / off /g" > $TMPDIR/dialog.tmp.off
        fi
      fi

      while ! $EXIT ; do

        if $CLOGopt ; then
          dialog --extra-button \
            --extra-label "ChangeLog" \
            --title "$DTITLE" \
            --backtitle "slackpkg $VERSION" $HINT \
            --checklist "Choose packages to $2:" \
            19 70 13 \
            --file $TMPDIR/dialog.tmp 2>$TMPDIR/dialog.out
        else
          dialog  --title "$DTITLE" \
            --backtitle "slackpkg $VERSION" $HINT \
            --checklist "Choose packages to $2:" \
            19 70 13 \
            --file $TMPDIR/dialog.tmp 2>$TMPDIR/dialog.out
        fi

        case $? in
          0|1)
            EXIT=true
                  dialog --clear
          ;;

          3)
            dialog --clear

            if $CLOGopt ; then

              if [ -s $TMPDIR/dialog.out ] ; then
                showChangeLogInfo $TMPDIR/dialog.out

                # regenerate the list of selected package from the patterns
                # in TMPDIR/dialog.out and the file TMPDIR/dialog.tmp.off

                PKGS_REGEX=$(cat $TMPDIR/dialog.out|sed "s/ /\\\|/g")

                cat $TMPDIR/dialog.tmp.off > $TMPDIR/dialog.tmp
                  # in case of install, dialog.tmp is to the format (1), otherwise the format (2)
                  # is used :
                  #
                  # format (1)
                  #   <pkg-name> <repository> on|off
                  # format (2)
                  #   <pkg-name> <repository> on|off <installed-version> --> <available-version>

                if [ "$2" == "install" ] ; then
                        sed -i -e "/^$PKGS_REGEX/ s= off$= on=" $TMPDIR/dialog.tmp
                else
                        sed -i -e "/^$PKGS_REGEX/ s= off = on =" $TMPDIR/dialog.tmp
                fi

              else
                dialog --title "ChangeLog" --msgbox "Please, select at least one package." 5 40
                # all packages are deselected ...
                cat $TMPDIR/dialog.tmp.off > $TMPDIR/dialog.tmp
              fi
            else
              EXIT=true
            fi
          ;;

          -1|124|125|126|127)
            EXIT=true
            dialog --clear
            echo -e "DIALOG ERROR:\n-------------" >> $TMPDIR/error.log
            cat $TMPDIR/dialog.out >> $TMPDIR/error.log
            echo "-------------" >> $TMPDIR/error.log
            echo "If you want to continue using slackpkg, disable the DIALOG option in" >> $TMPDIR/error.log
            echo "$CONF/slackpkg.conf and try again." >> $TMPDIR/error.log
            echo "Help us to make slackpkg a better tool - report bugs to the slackpkg" >> $TMPDIR/error.log
            echo "developers" >> $TMPDIR/error.log
            cleanup
          ;;
        esac
      done
      echo
      echo
      SHOWLIST=$(cat $TMPDIR/dialog.out | tr -d \")
      if [ -z "$SHOWLIST" ]; then
        echo "No packages selected for $2, exiting."
        cleanup
      fi
    } # END function showlist()

  else # (DIALOG=off)

      # Supersede original showlist() from core-functions.sh
      #
      # Show the lists and asks if the user want to proceed with that action
      # Return accepted list in $SHOWLIST
      #
      # This version show the repository to which each package belongs.
      #
    function showlist() {
      local ANSWER
      local i
      local SHOWREPO=false
      local REPONAME

      if echo "$CMD" | grep -qE "install|reinstall|upgrade|upgrade-all" ; then
        printf "[ %-24s ] [ %-40s ]\n" "Repository" "Package"
        SHOWREPO=true
      fi

      for i in $1; do
        if $SHOWREPO ; then
          REPONAME=$(grep -m 1 "${i%.*}" $TMPDIR/pkglist | cut -f1 -d" " | sed "s/SLACKPKGPLUS_//")
          printf "  %-24s     %-40s  \n" "$REPONAME" "$i"
        else
          echo $i;
        fi
      done | $MORECMD
      echo
      countpkg "$1"
      echo -e "Do you wish to $2 selected packages (Y/n)? \c"
      answer
      if [ "$ANSWER" = "N" -o "$ANSWER" = "n" ]; then
        cleanup
      else
        SHOWLIST="$1"
        continue
      fi
    } # END function showlist()

  fi # (DIALOG=on/off)



  #### ===== END SHOWLIST FUNCTIONS ====== ######


  function debug(){
    echo "DEBUG $(date +%H:%M:%S.%N) (${BASH_LINENO[*]}): $@" >&2
  } # END function debug()



  ### =========================== MAIN ============================ ###

  export LC_ALL=C

  if [ "$DOWNLOADONLY" == "on" ];then
    DELALL=off
    DOWNLOAD_ALL=on
  fi

  if [ -z "$VERBOSE" ];then
    VERBOSE=1
  fi


  if [ "$CMD" == "upgrade" -o "$CMD" == "upgrade-all" ]&&ls $ROOT/var/log/packages/*:* >/dev/null 2>&1;then
    echo "FATAL! There is some problem in packages database"
    echo "       or maybe an installation or upgrade in progress:"
    echo
    echo "   "$(cd $ROOT/var/log/packages/ ; ls *:*)
    echo
    echo "       If you continue you may corrupt packages database."
    echo "       Check or retry later"
    echo
    cleanup
  fi


  SPKGPLUS_VERSION="1.7.0"
  VERSION="$VERSION / slackpkg+ $SPKGPLUS_VERSION"
  

  if [ ! -e "$WORKDIR" ];then
    mkdir -p "$WORKDIR"
  fi

  if [ ! -e $WORKDIR/install.log ];then
    touch $WORKDIR/install.log
  fi

  if [ "$CMD" == "update" ];then
    # answer to "Do you really want to download all other files"
    # if there are new changes
    ANSWER="Y"
  fi

  if [ "$UPARG" != "gpg" ]&&[ "$CHECKGPG" = "on" ]&& ! ls -l $WORKDIR/gpg/GPG-KEY-slackware*.gpg >/dev/null 2>&1;then
    echo "FATAL! No Slackware GPG-KEY imported."
    if [ -e "$WORKDIR/ChangeLog.txt" ];then
      echo "If you are upgrading from an older release of slackpkg+, all keys must to be reimported."
    fi
    echo "Please run"
    echo "  # slackpkg update gpg"
    cleanup
  fi

    # Ensure each repository url has a trailing slash...
    #
  for PREPO in "${!MIRRORPLUS[@]}" ; do
    MIRRORPLUS[$PREPO]="${MIRRORPLUS[$PREPO]%/}/"
  done

  touch $TMPDIR/greylist.1
  if [ -e $CONF/greylist ];then
    cat $CONF/greylist|sed -e 's/#.*//'|grep -v -e '^#' -e '^$'|awk '{print $1}'|sort -u >$TMPDIR/greylist.1
    cat $TMPDIR/greylist.1|sed 's/^/SLACKPKGPLUS_/' >$TMPDIR/greylist.2
  fi

  INDEX=0
  PURE_PKGSPRIORITY=""
  for pp in ${PKGS_PRIORITY[@]} ; do
    repository=$(echo "$pp" | cut -f1 -d":")

    if [ "$pp" == "$repository" ] && grep -q "^SLACKPKGPLUS_${repository}[ ]" $WORKDIR/pkglist 2>/dev/null ; then
      pp="$repository:.*"
      PKGS_PRIORITY[$INDEX]="$repository:.*"
    fi

    if ! echo "$repository" | grep -qwE "$SLACKDIR_REGEXP" ; then
      PURE_PKGSPRIORITY=( ${PURE_PKGSPRIORITY[*]} $pp )
    fi
    ((INDEX++))
  done

  REPOPLUS=( $(echo "${REPOPLUS[*]} ${PURE_PKGSPRIORITY[*]} ${!MIRRORPLUS[*]}"|sed 's/ /\n/g'|sed 's/:.*//'|awk '{if(!a[$1]++)print $1}') )
  PRIORITY=( ${PRIORITY[*]} SLACKPKGPLUS_$(echo ${REPOPLUS[*]}|sed 's/ / SLACKPKGPLUS_/g') )

  # Test repositories
  for pp in ${REPOPLUS[*]};do
    echo "${MIRRORPLUS[$pp]}"|grep -q -e ^http:// -e ^https:// -e ^ftp:// -e ^file:// -e ^dir:/
    if [ $? -ne 0 ];then
      echo "Repository '$pp' not configured." >> $TMPDIR/error.log
      echo "Add:" >> $TMPDIR/error.log
      echo "MIRRORPLUS['$pp']=http://repoaddres/..." >> $TMPDIR/error.log
      echo "See documentation in /usr/doc/slackpkg+-* for details" >> $TMPDIR/error.log
      cleanup
    fi
  done

  if [ "$CMD" != "update" -a "$CMD" != "check-updates" ];then
    if [ $[$(date +%s)-$(date -d "$(ls -l --full-time $WORKDIR/pkglist 2>/dev/null|awk '{print $6,$7,$8}')" +%s)] -gt 86400 ];then
      echo
      echo "NOTICE: pkglist is older than 24h; you are encouraged to re-run 'slackpkg update'"
      echo
      sleep 1
    fi
  fi
  if [ "$CMD" != "update" -a "$CMD" != "check-updates" ];then
    if [ $CONF/slackpkgplus.conf -nt $WORKDIR/pkglist ];then
      echo
      echo "NOTICE: remember to re-run 'slackpkg update' after modifying slackpkgplus.conf"
      echo
      sleep 5
    fi
  fi


  # -- merge priorities from PKGS_PRIORITY with PRIORITY, as needed ...

  if [ ! -z "$PKGS_PRIORITY" -a "$CMD" != "update" ] ; then
    PREFIX=""

    for pp in ${PKGS_PRIORITY[*]} ; do
      repository=$(echo "$pp" | cut -f1 -d":")
      package=$(echo "$pp" | cut -f2- -d":")

      if [ ! -z "$repository" ] && [ ! -z "$package" ] ; then

        if ! echo "$repository" | grep -qwE "$SLACKDIR_REGEXP" ; then
          repository="SLACKPKGPLUS_${repository}"
        fi

        if [ -z "$PREFIX" ] ; then
          PREFIX=( ${repository}:$package )
        else
          PREFIX=( ${PREFIX[*]} ${repository}:$package )
        fi
      fi
    done

    [ ! -z "$PREFIX" ] && PRIORITY=( ${PREFIX[*]} ${PRIORITY[*]} )
  fi

  # -- This flag is set when running slackpkg to manage the multilib :
  #
  #      slackpkg install|upgrade|reinstall|remove <multilib_repository_name>
  #
  #    This is used by applyblacklist() to prevent silent exclusion of
  #    multilib package aaa_elflibs-compat32 when /etc/slackpkg/blacklist
  #    contains the pattern aaa_elflibs.
  #
  MLREPO_SELELECTED=false

  # -- Ensures the internal blacklist is empty
  #
  echo -n "" > ${TMPDIR}/blacklist.slackpkgplus


  if [ ! -z "$DOWNLOADCMD" ];then
    DOWNLOADER="$DOWNLOADCMD"
  else
    DOWNLOADER="wget $WGETOPTS --no-check-certificate --passive-ftp -O"
    if [ "$VERBOSE" = "0" ];then
      DOWNLOADER="wget $WGETOPTS --no-check-certificate -nv --passive-ftp -O"
    elif [ "$VERBOSE" = "2" ];then
      DOWNLOADER="wget $WGETOPTS --no-check-certificate --passive-ftp -O"
    elif [ "$VERBOSE" = "3" ];then
      DOWNLOADER="wgetdebug"
    elif [ "$CMD" = "update" ];then
      if [ "$CACHEUPDATE" == "on" ];then
        DOWNLOADER="wget $WGETOPTS --no-check-certificate -q --passive-ftp -O"
      else
        DOWNLOADER="wget $WGETOPTS --no-check-certificate -nv --passive-ftp -O"
      fi
    fi
  fi

  if [ "$CACHEUPDATE" == "on" ]&&[ "$CMD" == "update" -o "$CMD" == "check-updates" ];then
    CACHEDOWNLOADER=$DOWNLOADER
    CACHEDIR=$WORKDIR/cache
    mkdir -p $CACHEDIR
    find $CACHEDIR -mtime +30 -exec rm -f {} \;
    DOWNLOADER="cached_downloader"
  fi


  # Global variable required by givepriority()
  #
  PRIORITYIDX=1

  touch ${TMPDIR}/pkglist-pre
  for PREPO in ${REPOPLUS[*]};do
    pref=${MIRRORPLUS[$PREPO]}
    if [ "${pref:0:5}" = "dir:/" ];then
      localpath=$(echo "$pref" | cut -f2- -d":"|sed -e 's_/$__' -e 's_//_/_')
      MIRRORPLUS[$PREPO]="dir:$localpath/"
      if [ ! -d "$localpath" ];then
        continue
      fi
      ( cd $localpath
        find . -type f -name '*.t[blxg]z'|sed "s,^./,./SLACKPKGPLUS_$PREPO/,"|awk -f /usr/libexec/slackpkg/pkglist.awk|sort -k6 -rn >> ${TMPDIR}/pkglist-pre
      )
    fi
  done

  touch ${TMPDIR}/priority.filters

  if [[ "$CMD" == "upgrade" || "$CMD" == "upgrade-all" ]] && [ "$ALLOW32BIT" == "on" ] ; then
    ARCH="\($ARCH\)\|\([i]*[3456x]86[^_]*\)"
    echo -e "i[3456]86\nx86" > $TMPDIR/greylist.32bit
  fi

  if [ "$CMD" == "install" ] || [ "$CMD" == "upgrade" ] || [ "$CMD" == "reinstall" ] || [ "$CMD" == "remove" ] ; then

    NEWINPUTLIST=""
    PRIORITYLIST=""

      # The priorities in PRIORITYLIST_SX :
      #   * are *all* of kind ".*:<pattern>"
      #   * are defined to handle cases where a pattern, with version and/or a build number
      #     but without any repository, is passed to install|upgrade (ex: install basename-1.0.1)
      #
      # Since there's no way to distinguish patterns with version/build number to other, priorities
      # of kind ".*:<pattern>" are also generated for patterns without version/build number. As a
      # consequence, these priorities could interfer with other defined priorities (1). To prevent
      # this, these priorities are handled after all other priorities.
      #
    PRIORITYLIST_SX=""

    for pref in $INPUTLIST ; do
      PRIORITY_FILTER_RULE=""

      # You can specify 'slackpkg install .' that is an alias of 'slackpkg install dir:./'
      if [ "$pref" == "." ];then
        pref="dir:./"
      fi

      # You can specify 'slackpkg install file:package-1.0-noarch-1my.txz' on local disk;
      # optionally you can add absolute or relative path.
      if echo "$pref" | egrep -q "file:.*\.t.z$" ; then
        package=$(echo "$pref" | cut -f2- -d":")
        localpath=$(dirname $package)
        package=$(basename $package)
        if [ ${localpath:0:1} != "/" ];then
          localpath=$(pwd)/$localpath
        fi
        repository=file$(grep ^SLACKPKGPLUS_file ${TMPDIR}/pkglist-pre|awk '{print $1}'|uniq|wc -l)
        echo "./SLACKPKGPLUS_$repository/$package"|awk -f /usr/libexec/slackpkg/pkglist.awk >> ${TMPDIR}/pkglist-pre
        MIRRORPLUS[$repository]="file:/$localpath/"
        PRIORITYLIST=( ${PRIORITYLIST[*]} SLACKPKGPLUS_${repository}:$package )
        REPOPLUS=( ${repository} ${REPOPLUS[*]} )
        package=$(cutpkg $package)

          # require to add rule "$repository $package" in the priority filter
        PRIORITY_FILTER_RULE="${repository} ${package}"

      # You can specify 'slackpkg install dir:directory' on local disk, where 'directory' have a relative or absolute path
      elif [ "${pref:0:4}" = "dir:" ]; then
        localpath=$(echo "$pref" | cut -f2- -d":"|sed 's_/$__')
        if [ ! -d "$localpath" ];then
          continue
        fi
        repository=dir$(grep ^SLACKPKGPLUS_dir ${TMPDIR}/pkglist-pre|awk '{print $1}'|uniq|wc -l)
        if [ ${localpath:0:1} != "/" ];then
          localpath=$(pwd)/$localpath
        fi
        ( cd $localpath
          find . -type f -name '*.t[blxg]z'|sed "s,^./,./SLACKPKGPLUS_$repository/,"|awk -f /usr/libexec/slackpkg/pkglist.awk|sort -k6 -rn >> ${TMPDIR}/pkglist-pre
        )
        MIRRORPLUS[$repository]="file:/$localpath/"
        PRIORITYLIST=( ${PRIORITYLIST[*]} SLACKPKGPLUS_${repository}:.* )
        REPOPLUS=( ${repository} ${REPOPLUS[*]} )
        package=SLACKPKGPLUS_$repository

          # require to add rule "$repository .*" in the priority filter
        PRIORITY_FILTER_RULE="${repository} .*"

      # You can specify 'slackpkg install http://mysite.org/myrepo/package-1.0-noarch-1my.txz' to install a package from remote path
      # without manual download. You can use http,https,ftp repositories
      elif echo "$pref" | egrep -q "^(https?|ftp)://.*/.*-[^-]+-[^-]+-[^\.]+\.t.z$" ;then
        repository=$(echo "$pref" | cut -f1 -d":")
        repository=$repository$(grep ^SLACKPKGPLUS_$repository[0-9] ${TMPDIR}/pkglist-pre|awk '{print $1}'|uniq|wc -l)
        MIRRORPLUS[$repository]=$(dirname $pref)"/"
        package=$(basename $pref)
        echo "./SLACKPKGPLUS_$repository/$package"|awk -f /usr/libexec/slackpkg/pkglist.awk >> ${TMPDIR}/pkglist-pre
        PRIORITYLIST=( ${PRIORITYLIST[*]} SLACKPKGPLUS_${repository}:$package )
        REPOPLUS=( ${repository} ${REPOPLUS[*]} )
        package=$(cutpkg $package)

          # require to add rule "${repository} ${package}" in the priority filter
        PRIORITY_FILTER_RULE="${repository} ${package}"

      # You can specify 'slackpkg install http://mysite.org/myrepo' to list remote directory
      elif echo "$pref" | egrep -q "^(https?|ftp)://.*/.*" ;then
        repository=$(echo "$pref" | cut -f1 -d":")
        repository=$repository$(grep ^SLACKPKGPLUS_$repository[0-9] ${TMPDIR}/pkglist-pre|awk '{print $1}'|uniq|wc -l)
        lftp $pref -e "ls;quit" 2>/dev/null|awk '{print $NF}'|egrep '^.*-[^-]+-[^-]+-[^\.]+\.t.z$'|sort -rn| \
          awk '{print "./SLACKPKGPLUS_'$repository'/"$NF}'|awk -f /usr/libexec/slackpkg/pkglist.awk >> ${TMPDIR}/pkglist-pre
        MIRRORPLUS[$repository]=$(echo "$pref" |sed 's_/$__')"/"
        PRIORITYLIST=( ${PRIORITYLIST[*]} SLACKPKGPLUS_${repository}:.* )
        REPOPLUS=( ${repository} ${REPOPLUS[*]} )
        package=SLACKPKGPLUS_$repository

          # require to add rule "${repository} .*" in the priority filter
        PRIORITY_FILTER_RULE="${repository} .*"

      # You can specify 'slackpkg install reponame:packagename'
      elif echo "$pref" | grep -q "^[-_[:alnum:]]\+[:][a-zA-Z0-9]\+" ; then

        if [ "$CMD" == "install" ] || [ "$CMD" == "upgrade" ] || [ "$CMD" == "reinstall" ] ; then
          repository=$(echo "$pref" | cut -f1 -d":")
          package=$(echo "$pref" | cut -f2- -d":")

            # require to add rule "${repository} ${package}" in the priority filter
          PRIORITY_FILTER_RULE="${repository} ${package}"

          if ! echo "$repository" | grep -qwE "$SLACKDIR_REGEXP" ; then
            repository="SLACKPKGPLUS_${repository}"
          fi

          PRIORITYLIST=( ${PRIORITYLIST[*]} ${repository}:$package )
        fi

      # You can specify 'slackpkg install reponame' where reponame is a thirdy part repository
      elif grep -q "^SLACKPKGPLUS_${pref}[ ]" ${WORKDIR}/pkglist ${TMPDIR}/pkglist-pre ; then

        echo "$pref" | grep -qi "multilib" && MLREPO_SELELECTED=true

        if $MLREPO_SELELECTED ; then
          if [ "$CMD" == "install" ] ; then
            internal_blacklist "glibc-debug"
          elif [ "$CMD" == "remove" ] ; then
            internal_blacklist "glibc"
            internal_blacklist "gcc"
          fi
        fi

          # require to add rule "${pref} .*" in the priority filter
        PRIORITY_FILTER_RULE="${pref} .*"

        package="SLACKPKGPLUS_${pref}"
        PRIORITYLIST=( ${PRIORITYLIST[*]} SLACKPKGPLUS_${pref}:.* )

      # You can specify 'slackpkg install reponame' where reponame is an official repository (slackware,slackware64,extra...)
      elif grep -q "^${pref}[ ]" ${WORKDIR}/pkglist ; then

        # -- ${pref} relates to one of the standard directories (ie
        #    slackware,slackware64,testing,extra,...). In this case,
        #    packages is set to "^${pref}" to avoid packages outside
        #    the given "directories" to be selected. For instance,
        #    without this, if slackpkg+ is configured with the
        #    repositories "multilib" and "microlinux", running
        #    "slackpkg install slackware64" leads to install packages
        #    from slackware64 directory, but also packages from
        #    "multilib" and "microlinux" repositories, because packages
        #    from these repositories are stored in directories whose
        #    names include the word "slackware64".
        #
        package="^${pref}"

          # require to add rule "${pref} .*" in the priority filter
        PRIORITY_FILTER_RULE="${pref} .*"

      # You can specify 'slackpkg install argument' where argument is a package name, part of package name, directory name in repository
      else
          # require to add rule ".* ${pref}" in the priority filter
        PRIORITY_FILTER_RULE=".* ${pref}"

        package=$pref
        AUTOPRIORITY=" $AUTOPRIORITY -e $package "

        if [ "$CMD" == "install" ] || [ "$CMD" == "upgrade" ] ; then
          PRIORITYLIST_SX=( ${PRIORITYLIST_SX[*]} ".*:${package}" )
        fi
      fi

      package=$(echo $package|sed 's/\.t[blxg]z$//')

      [ ! -z "${PRIORITY_FILTER_RULE}" ] && echo "${PRIORITY_FILTER_RULE}" >> ${TMPDIR}/priority.filters

      # -- only insert "package" if not in NEWINPUTLIST
      echo "$NEWINPUTLIST" | grep -qw "${package}" || NEWINPUTLIST="$NEWINPUTLIST $package"
      
    done # pref in $INPUTLIST

    INPUTLIST=$NEWINPUTLIST

    if [ ! -z "$PRIORITYLIST" ] || [ ! -z "$PRIORITYLIST_SX" ] ; then
        # PRIORITYLIST_SX includes priority of kind .*:pattern. This kind of priority must be handled
        # after all others, and are, by consequence, added at the end.
        #
      NEWPRIORITY=( ${PRIORITYLIST[*]} ${PRIORITY[*]} ${PRIORITYLIST_SX[*]} )
      unset PRIORITY

      # -- This is to avoid duplicated priority rules in the variable
      #    PRIORITY
      #
      for np in ${NEWPRIORITY[*]} ; do
        ADD_PRIORITY=true
        for cp in ${PRIORITY[*]} ; do
          if [ "$np" == "$cp" ] ; then
            ADD_PRIORITY=false
            break
          fi
        done

        if $ADD_PRIORITY ; then
          PRIORITY=( ${PRIORITY[*]} $np )
        fi
      done
    fi
  fi # "$CMD" == "install" / "upgrade" / "reinstall" / "remove"

  if [ "$CMD" == "search" ] || [ "$CMD" == "file-search" ] ; then
    PATTERN=$(echo $ARG | sed -e 's/\+/\\\+/g' -e 's/\./\\\./g' -e 's/ /\|/g' -e 's/^\///')
    searchPackages $PATTERN

    case $CMD in
      search)
        if [ "$LIST" = "" ]; then
          echo -e "No package name matches the pattern."
        else
          echo -e "The list below shows all packages with name matching \"$PATTERN\".\n"
          searchlistEX "$LIST"
          echo -e "\nYou can search specific files using \"slackpkg file-search file\".\n"
        fi
      ;;

      file-search)
        if [ "$LIST" = "" ]; then
          echo -e "No packages contains \"$PATTERN\" file."
        else
          echo -e "The list below shows the packages that contains \"$PATTERN\" file.\n"
          searchlistEX "$LIST"
          echo -e "\nYou can search specific packages using \"slackpkg search package\".\n"
        fi
      ;;
    esac

    cleanup
  fi # "$CMD" == "search" / "file-search"

  if [ "$CMD" == "check-updates" ] ; then

    [ ! -e ~/.slackpkg ] && mkdir ~/.slackpkg
    echo -n "" > ~/.slackpkg/updated-repos.txt

    UPDATES=false

    touch ${TMPDIR}/waiting

    if [ $VERBOSE -eq 3 ];then
      checkchangelog
      ERR=$?
    else
      if [[ ! ${SPINNING} = "off" ]]; then
        echo -n "Searching for updates... "
        spinning ${TMPDIR}/waiting &
      fi
      exec 3>&1 4>&2
      TTYREDIRECTION=1
      checkchangelog >/dev/null 2>&1
      ERR=$?
      TTYREDIRECTION=""
      exec 1>&3 2>&4
    fi
    if [ $ERR -ne 0 ]; then
    
        # -- Note:
        #     checkchangelog() download the ChangeLog.txt and stores it
        #     in ${TMPDIR}

        # extract the slackpkgplus repositories md5 from the ChangeLog.txt
        # files (in ${WORKDIR} and ${TMPDIR} to identify updates in Slackware
        # repository.
        #
      grep -v "^SLACKPKGPLUS_.*\[MD5\] " ${WORKDIR}/ChangeLog.txt > ${TMPDIR}/ChangeLog.old
      grep -v "^SLACKPKGPLUS_.*\[MD5\] " ${TMPDIR}/ChangeLog.txt > ${TMPDIR}/ChangeLog.new
      
      if [ "$(md5sum ${TMPDIR}/ChangeLog.old | cut -f1 -d' ')" != "$(md5sum ${TMPDIR}/ChangeLog.new | cut -f1 -d' ')" ] ; then
              echo "slackware" > ${TMPDIR}/updated-repos.txt
      fi
      
        # -- get the list of the repositories configured before this call to check-updates
        #
      grep "^SLACKPKGPLUS_.*\[MD5\] " ${WORKDIR}/ChangeLog.txt | sed 's/^SLACKPKGPLUS_//; s/\[MD5\]//' | cut -f1 -d" "> ${TMPDIR}/selected.3pr

        # create pseudo changelogs for the selected 3rd party repositories
        #
      grep "^SLACKPKGPLUS_.*\[MD5\] " ${WORKDIR}/ChangeLog.txt | sort  > "${TMPDIR}/3rp-ChangeLog.old"
      grep "^SLACKPKGPLUS_.*\[MD5\] " ${TMPDIR}/ChangeLog.txt | sort > "${TMPDIR}/3rp-ChangeLog.new"
      
        # from the pseudo changelogs, find the updated 3rd party repositories and add them
        # to the updates report file
        #
      comm -1 -3  "${TMPDIR}/3rp-ChangeLog.old" \
                  "${TMPDIR}/3rp-ChangeLog.new" \
              | sed -e "s/^SLACKPKGPLUS_//" -e "s/\[MD5\]//" \
              | cut -f1 -d" " | grep -f ${TMPDIR}/selected.3pr >> "${TMPDIR}/updated-repos.txt"

              # when TMPDIR/updated-repos.txt is not empty , it contains the
              # names of the updated repositories.
              #
              # NOTE:
              #  at this point, updated-repos.txt can be empty when user
              #  has added a repository in REPOPLUS and run "slackpkg check-updates"
              #  instead (or prior to) "slackpkg update"
              
      [ -s "${TMPDIR}/updated-repos.txt" ] && UPDATES=true
    fi
    rm -f ${TMPDIR}/waiting
    
    if $UPDATES ; then
      echo "News on ChangeLog.txt"
      
      printf "\n  [ %-24s ] [ %-20s ]\n" "Repository" "Status"
      
      for REPO in slackware ${REPOPLUS[*]}; do
        if grep -q "^${REPO}$"  ${TMPDIR}/updated-repos.txt ; then
          printf "    %-24s     %-20s \n" "$REPO" "AVAILABLE UPDATES"
        else
          printf "    %-24s     %-20s \n" "$REPO" "   Up to date   "
        fi
      done

        # save ${TMPDIR}/updates-repos.txt in ~/.slackpkg/updated-repos.txt
        #
      cat ${TMPDIR}/updated-repos.txt > ~/.slackpkg/updated-repos.txt
    else
      echo "No news is good news"
      # Suppress the "pkglist is older than 24h" notice
      touch $WORKDIR/pkglist
    fi

    cleanup
  fi # "$CMD" == "check-updates"

fi
