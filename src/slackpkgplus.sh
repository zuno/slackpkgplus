# vim: set tabstop=2 shiftwidth=2 expandtab 

# Thanks to AlienBob and phenixia2003 (on LQ) for contributing
# A special thanks to all packagers that make slackpkg+ useful

declare -A MIRRORPLUS
declare -A SBO
declare -A NOTIFYMSG

  # regular expression used to distinguish the 3rd party repositories from the standard slackware directories.
  #
SLACKDIR_REGEXP="^((slackware)|(slackware64)|(extra)|(pasture)|(patches)|(testing))$"

  # CLOG_PKGREGEX : regular expression used to find package entry in ChangeLog files
  # CLOG_SEPREGEX : regular expression that match the "standard" entry separator in a ChangeLog file
CLOG_PKGREGEX="^[^ ]*:[ ]+(added|moved|rebuilt|upgraded)"
CLOG_SEPREGEX="^[+][-]+[+][ ]*$"

if [ -e $CONF/slackpkgplus.conf ];then
  # You can override GREYLIST WGETOPTS SLACKPKGPLUS VERBOSE USEBL ALLOW32BIT SENSITIVE_SEARCH from command-line
  EXTLEGACYBL=$LEGACYBL
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
  EXTUSETERSE=$USETERSE
  EXTTERSESEARCH=$TERSESEARCH
  EXTPROXY=$PROXY

  # Color escape codes
  c_blk='\033[1;30m'
  c_red='\033[1;31m'
  c_grn='\033[1;32m'
  c_yel='\033[1;33m'
  c_blu='\033[1;34m'
  c_mag='\033[1;35m'
  c_cyn='\033[1;36m'
  c_gry='\033[1;90m'
  c_wht='\033[1;67m'
  c_hid='\033[8m'
  c_off='\033[0m'

  . $CONF/slackpkgplus.conf

  c_upgr="${c_upgr:-$c_red}"
  c_inst="${c_inst:-$c_grn}"
  c_mask="${c_mask:-$c_gry}"
  c_unin="${c_unin:-$c_blu}"

  LEGACYBL=${EXTLEGACYBL:-$LEGACYBL}
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
  USETERSE=${EXTUSETERSE:-$USETERSE}
  TERSESEARCH=${EXTTERSESEARCH:-$TERSESEARCH}
  PROXY=${EXTPROXY:-$PROXY}

  if [ "$PROXY" == "off" ];then
    unset http_proxy
    unset https_proxy
  else
    http_proxy=$PROXY
    https_proxy=$PROXY
    export http_proxy https_proxy
  fi

  if [ "$USETERSE" == "on" ];then
    TERSE=0    # note that TERSE=0 means TERSE ENABLED; undocumentated feature in installpkg(8)
  else
    TERSE=
  fi
  export TERSE

  USEBLACKLIST=true
  if [ "$USEBL" == "off" -o "$USEBL" == "0" ];then
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
  # function needs_restarting()
  # function handle_event()
  # function remove_pkg()
  # function installpkg() // if DOWNLOADONLY=on override /sbin/installpkg
  # function upgradepkg() // if DOWNLOADONLY=on override /sbin/upgradepkg
  # function upgrade_pkg()
  # function install_pkg()
  # function wgetdebug()
  # function cached_downloader()
  # function getpkg()
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

    # Patching makelist() original function to accept pkglist-pre
  eval "$(type makelist | sed -e $'1d;2c\\\nmakelist()\n' \
                              -e "/in package list/s/tr -d '\\\\\\\\'/tr -d '\\\\\\\\*'/" \
                              -e 's,cat ${WORKDIR}/pkglist > ${TMPDIR}/pkglist,cat $TMPDIR/pkglist-pre ${WORKDIR}/pkglist | applyblacklist > ${TMPDIR}/pkglist,' \
         )"

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
    if ! $USEBLACKLIST ;then
      >${TMPDIR}/blacklist
    fi
    cat > ${TMPDIR}/inblacklist
    grep -vE ${BLKLOPT} -f ${TMPDIR}/blacklist -f ${TMPDIR}/blacklist.slackpkgplus ${TMPDIR}/inblacklist >${TMPDIR}/outblacklist
    cat ${TMPDIR}/outblacklist
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
    local retval=${EXIT_CODE:-0}
    [ ! -z "$PENDING_UPDATES" ]&&retval=$PENDING_UPDATES

    if ! ls -L /usr/bin/vi >/dev/null 2>&1 && [ ! -z "$LINKVI" ];then
      echo "
      An update has removed or damaged your VI symbolic link so you may be not
      able to use VI (vim, elvis, nvi,...)
      You need to manually run '/var/lib/pkgtools/setup/setup.vi-ex' to choose
      your default VI editor or create the link yourself.
      This may happen when you upgrade from slackware 14.2 to slackware 15.0
      " >> $TMPDIR/info.log
    fi
    needs_restarting

    if [ "$CMD" == "info" ];then
      DETAILED_INFO=${DETAILED_INFO:-none}
      [[ "$DETAILED_INFO" != "none" ]]&&more_info
    fi
    rm -f ${TMPDIR}/waiting
    if [ "$CMD" == "update" ];then
      if [ -e $TMPDIR/pkglist.sbo ];then
        cat $TMPDIR/pkglist.sbo >> $WORKDIR/pkglist
      fi
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
    if [ -s $TMPDIR/error.log -o -s $TMPDIR/info.log -o -s $TMPDIR/fatal.log ];then
      echo -e "\n\n=============================================================================="
    fi
    if [ -e $TMPDIR/error.log ]; then
      retval=1
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
    if [ -s $TMPDIR/fatal.log ]; then
      retval=2
      echo
      echo "=============================================================================="
      echo 
      echo "                        !!! F A T A L !!!"
      echo "          Some operation has failed and need attention!!"
      echo
      cat $TMPDIR/fatal.log
      echo
      echo "=============================================================================="
    fi
    [ ! -e $WORKDIR/pkglist ]&&touch $WORKDIR/pkglist
    [ ! -e $WORKDIR/CHECKSUMS.md5 ]&&touch $WORKDIR/CHECKSUMS.md5
    echo
    rm -f /var/lock/slackpkg.$$
    if [ $VERBOSE -lt 3 -a -z "$DEBUG" ];then
      rm -rf $TMPDIR
    fi
    exit $retval
  } # END function cleanup()

    # From slackpkg (with some improving)
    #
    # Checks if a critical package were upgraded by Slackpkg.
    # The /var/run/needs_restarting file contains the list of upgraded
    # packages.
    #
    # The file only is created if /var/run filesystem type is tmpfs so
    # the reboot will clean it
  function needs_restarting() {
    NEED_RESTART="$(
      find $ROOT/var/log/packages/ -cnewer $TMPDIR/timestamp -type f \( \
        -name "kernel-generic-[0-9]*" -o \
        -name "kernel-huge-[0-9]*" -o \
        -name "openssl-solibs-[0-9]*" -o \
        -name "openssl-[0-9]*" -o \
        -name "glibc-[0-9]*" -o \
        -name "aaa_glibc-solibs-[0-9]*" -o \
        -name "eudev-[0-9]*" -o \
        -name "elogind-[0-9]*" -o \
        -name "dbus-[0-9]*" \) | \
      awk -F/ '{ print $NF }'
    )"
    if [ ! -z "$NEED_RESTART" ];then
      echo "NOTE: Some installed or upgraded package may need reboot: " >> $TMPDIR/info.log
      echo "$NEED_RESTART"|sed 's/^/           /'                       >> $TMPDIR/info.log
      if [ "$(stat -f -c %T /var/run/)" = "tmpfs" ]; then
        echo "$NEED_RESTART" >> $ROOT/var/run/needs_restarting
        echo "See /var/run/needs_restarting for review this list"       >> $TMPDIR/info.log
      fi
    fi
  }

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
      else
        echo "Remove FAILED: $i : please retry." >> $TMPDIR/fatal.log
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
    ls -1 $ROOT/var/log/packages/ > $TMPDIR/tmplist

    for i in $SHOWLIST; do
      PKGFOUND=$(grep -m1 -e "^$(echo $i|rev|cut -f4- -d-|rev)-[^-]\+-[^-]\+-[^-]\+$" $TMPDIR/tmplist)
      REPOPOS=$(grep -m1 " $(echo $i|sed 's/\.t.z//') "  $TMPDIR/pkglist|awk '{print $1}'|sed 's/SLACKPKGPLUS_//')
      getpkg $i upgradepkg Upgrading $REPOPOS $PKGFOUND
      if [ "$DOWNLOADONLY" != "on" ];then
        if [ -e "$ROOT/var/log/packages/$(echo $i|sed 's/\.t.z//')" ];then
          FDATE=$(ls -l --full-time $ROOT/var/log/packages/$(echo $i|sed 's/\.t.z//') |awk '{print $6" "$7}'|sed -r -e 's/\.[0-9]{9}//' -e 's,-,/,' -e 's,-,/,')
          echo "$FDATE upgraded:    $i  [$REPOPOS]  (was $PKGFOUND)" >> $WORKDIR/install.log
        else
          echo "Upgrade FAILED: $REPOPOS:$i : please retry." >> $TMPDIR/fatal.log
        fi
      fi
    done
    [ "$DOWNLOADONLY" != "on" ]&&handle_event "upgrade"
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
      getpkg $i installpkg Installing $REPOPOS
      if [ "$DOWNLOADONLY" != "on" ];then
        if [ -e "$ROOT/var/log/packages/$(echo $i|sed 's/\.t.z//')" ];then
          FDATE=$(ls -l --full-time $ROOT/var/log/packages/$(echo $i|sed 's/\.t.z//') |awk '{print $6" "$7}'|sed -r -e 's/\.[0-9]{9}//' -e 's,-,/,' -e 's,-,/,')
          echo "$FDATE $INSTALL_T $i  [$REPOPOS]" >> $WORKDIR/install.log
        else
          echo "Install FAILED: $REPOPOS:$i : please retry." >> $TMPDIR/fatal.log
        fi
      fi
    done
    [ "$DOWNLOADONLY" != "on" ]&&handle_event "install"
  } # END function install_pkg()

  ##### ====== END INSTALL/POSTINSTALL FUNCTIONS ====== #####


  ##### ====== DOWNLOADERS ====== ######

    # Resolve some issue with wget2
    #
  function wget2(){
    WGET2CMD="$@"
    WGET2PATH=$(echo "$WGET2CMD"|sed -r "s,.*-O ([^ ]+) .*,\1,")
    WGET2DIR=$(echo "$WGET2PATH"|sed -r "s,/[^/]*$,,")
    WGET2CMD="$(echo "$WGET2CMD"|sed -r "s,$WGET2DIR/,,")"
    cd $WGET2DIR
    /usr/bin/wget2 $WGETOPTS $WGET2CMD
    cd - >/dev/null
  }
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
      ChangeLog.txt) TOCACHE=1 ; CURREPO=$(basename $1|sed -e "s/ChangeLog//" -e "s/^-//" -e "s/\.txt//") ;;
      GPG-KEY) TOCACHE=0 ; CURREPO=${1/*gpgkey-tmp-/};;
      FILELIST.TXT) TOCACHE=1 ;;
      SLACKBUILDS.TXT.gz) TOCACHE=1 ; CURREPO=SBo ;;
      slackbuilds-current-*.tar.gz) TOCACHE=0 ; CURREPO=SBo-cur ;;
    esac
    if [ -z "$CURREPO" ]; then
      CURREPO=slackware
    fi

    [ $SRCBASE != "ChangeLog.txt" ]||[ -z "$LEVEL" -o "$LEVEL" == "1" ]&&printf "    File: %-20s -> %-20s .." "$CURREPO" "$SRCBASE"
    [ $VERBOSE -eq 3 ]&&echo -n " ($CACHEFILE) "
    if [ $TOCACHE -eq 1 ];then
      curl --max-time 10 --location --head $SRCURL 2>/dev/null|tac|sed '/^HTTP/q'|tac|grep -v -i -e ^Date: -e ^Set-Cookie: -e ^Expires: -e ^X-Varnish:|sed $'s/\r//' > $TMPDIR/cache.head
      echo "Url: $SRCURL" >> $TMPDIR/cache.head
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
        [ $VERBOSE -eq 3 ]&&(echo;cat $CACHEDIR/$CACHEFILE.head|sed 's/^/  /')
        if diff $CACHEDIR/$CACHEFILE.head $TMPDIR/cache.head >/dev/null;then
          [ $VERBOSE -eq 3 ]&&echo "Cache valid!   If not please remove manually $CACHEDIR/$CACHEFILE !"
          echo " Cached."
          cp $CACHEDIR/$CACHEFILE $1
          return $?
        fi
        rm -f $CACHEDIR/$CACHEFILE $CACHEDIR/$CACHEFILE.head 2>/dev/null
      fi
      echo -n " Downloading... "
      [[ "$WGETOPTS $FLAG" =~ -q ]]||echo
      $CACHEDOWNLOADER $1 $SRCURL
      ERR=$?
      echo
      if [ "$(ls -l $1 2>/dev/null|awk '{print $5}')" == "$(grep -i Content-Length: $TMPDIR/cache.head|awk '{print $2}')" ];then
        cp $1 $CACHEDIR/$CACHEFILE 2>/dev/null
        cp $TMPDIR/cache.head $CACHEDIR/$CACHEFILE.head 2>/dev/null
      fi
    else
      echo " Downloading... "
      $CACHEDOWNLOADER $1 $SRCURL
      ERR=$?
      echo
    fi
    return $ERR

  } # END function cached_downloader()

  ##### ====== END DOWNLOADERS ====== ######


  ##### ====== CORE FUNCTION ====== ######
    # Extends getpkg() original function
    # (rename getpkg -> getpkg_old, then redefine getpkg to call it)
  eval "$(type getpkg | sed -e $'1d;2c\\\ngetpkg_old()\n' -e 's/Upgrading /Upgrading $5 => [$4]:/' -e 's/Installing /Installing [$4]:/' -e 's/nPackage/tPackage/g')"
  function getpkg(){
    local c
    local q
    q=$(echo $SHOWLIST|wc -w)
    c=$(echo $SHOWLIST|sed 's/ /\n/g'|grep -n ^$1|cut -f1 -d:)
    echo -n "[$c/$q]"
    getpkg_old "$@"
    return $?
  } # END function getpkg()

    # Override the get_gpg_key to rollback slackpkg 15.0.5 gpg-key import method
  function get_gpg_key(){
    getfile ${SOURCE}GPG-KEY $TMPDIR/gpgkey
  }

    # Override the slackpkg getfile().
    # The new getfile() download all file needed from all defined repositories
    # then merge all in a format slackpkg-compatible
  function getfile(){
    local URLFILE
    URLFILE=$1
    PREPO=slackware
    if [ $(basename $1) = "PACKAGES.TXT" ];then
      PREPO=$(echo $1|awk -F/ '{print $(NF-1)}')
    fi

    if echo $URLFILE|grep -q /SBO_;then
      local PRGNAM
      local DESTFILE=$2
      local NAMEPKG
      if echo $URLFILE|grep -q "\.\.asc$";then return 0;fi
      PREPO=$(echo $URLFILE|sed -r 's#^.*/SBO_([^/]+)/.*$#\1#')
      if [ "$PREPO" == "current" ];then
        SBO['current']=${SBO['current']}plain/
      fi
      NAMEPKG=$(basename $URLFILE .)
      PRGNAM=$(echo $NAMEPKG|sed "s#-[^-]*-sbo-$PREPO\$##")
      URLFILE=$(dirname $URLFILE)
      URLFILE=$(echo $URLFILE|sed "s#^.*/SBO_$PREPO/#${SBO[$PREPO]}#")
      DESTFILE=$(dirname $DESTFILE)
      if [ "$PREPO" == "current" ];then
        rm -rf ${DESTFILE}
        mkdir -p ${DESTFILE}
        (
          cd ${DESTFILE}
          wget -r -np $WGETOPTS -nv -nH $WGETOPTS $URLFILE/
          mv slackbuilds/plain/*/$PRGNAM $NAMEPKG
          rm -f $NAMEPKG/index.html
          rm -f robots.txt
          rm -rf slackbuilds/
          echo "Downloaded in $(readlink -f ${DESTFILE})"
        )
      else
        rm -rf ${DESTFILE}
        mkdir ${DESTFILE}
        wget $WGETOPTS -nv ${URLFILE}.tar.gz -O ${DESTFILE}/${PRGNAM}.tar.gz
        (
          cd $DESTFILE
          tar xf ${PRGNAM}.tar.gz
          mv ${PRGNAM} ${NAMEPKG}
          rm -f ${PRGNAM}.tar.gz
          echo "Downloaded in $(readlink -f ${DESTFILE})"
        )
      fi
      return 0

    fi

    if [ $(basename $1) = "CHECKSUMS.md5.asc" ];then
      if [ -e $TMPDIR/signaturedownloaded ];then
        echo "                Done."
        return
      fi
      echo "                Signatures"
    fi
    if [ $(basename $1) = "ChangeLog.txt" ];then
      echo "                ChangeLogs"
    fi

    if echo $1|grep -E -q '/SLACKPKGPLUS_(file|dir|http|https|ftp)[0-9].*\.asc$';then
      return 0
    fi

    if [ ${URLFILE:0:1} = "/" ];then
      URLFILE="file:/$URLFILE"
    fi
    if echo $URLFILE|grep -q /SLACKPKGPLUS_;then
      PREPO=$(echo $URLFILE|sed -r 's#^.*/SLACKPKGPLUS_([^/]+)/.*$#\1#')
      URLFILE=$(echo $URLFILE|sed "s#^.*/SLACKPKGPLUS_$PREPO/#${MIRRORPLUS[$PREPO]}#")
    fi

    if echo $URLFILE | grep "dir:/"|grep -q "/PACKAGES.TXT$";then
      touch $2
      return 0
    fi
    if echo $URLFILE | grep "dir:/"|grep -q "/MANIFEST.bz2$";then
      echo -n|bzip2 -c >$2
      return 0
    fi

    URLFILE=$(echo $URLFILE|sed -e 's_^dir:/_file://_')

    if echo $URLFILE | grep -q "^file://" ; then
      URLFILE=${URLFILE:6}
      if [ -f $URLFILE ];then
        [[ "$FLAG" == "-q" || ! "$WGETOPTS" =~ -q ]]&&echo -e "\tLinking $URLFILE"
        ln -s $URLFILE $2
      else
        return 1
      fi
    elif echo $URLFILE|grep -q -E dir:/.*asc$;then
      return 0
    else
      URLFILE=${URLFILE/dir:/:}
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
        fi
      fi
    fi

    if [ $(basename $1) = "FILELIST.TXT" ];then
      [ ! -s $TMPDIR/FILELIST.TXT ]&&echo  > $TMPDIR/FILELIST.TXT
      touch $TMPDIR/pkglist.sbo
      for SBOKEY in ${!SBO[*]};do
        SBOURL=${SBO[$SBOKEY]}
        if [ "$SBOKEY" == "current" ];then
          SBOURL=${SBOURL%/}/
          SBOtag=$(basename $(curl --max-time 10 --location -s $SBOURL|grep "/slackbuilds/tag/?h=" |head -1|grep -oE "href='[^']+'"|cut -f2 -d"'"|grep tar.gz))
          SBOlast=$(cat $WORKDIR/sbolist_${SBOKEY}.tag 2>/dev/null)
          if echo $SBOtag|grep -q slackbuilds-current-.*tar.gz && [ "$SBOtag" != "$SBOlast" ];then
            $DOWNLOADER $TMPDIR/$SBOtag ${SBOURL}snapshot/$SBOtag
            (
              cd $TMPDIR
              tar xf $TMPDIR/*$SBOtag
              cd slackbuilds-current*/
              find . -name \*.info|while read SBOinfo;do
                source $SBOinfo
                echo $PRGNAM $VERSION $(dirname $SBOinfo)
              done > $WORKDIR/sbolist_${SBOKEY}
              echo $SBOtag > $WORKDIR/sbolist_${SBOKEY}.tag
            )
          fi
        else
          SBOURL=${SBOURL%/}/
          $DOWNLOADER $TMPDIR/SLACKBUILDS.TXT.gz ${SBOURL}SLACKBUILDS.TXT.gz
          zcat $TMPDIR/SLACKBUILDS.TXT.gz |awk '{
                                                  if($2=="NAME:")       name=$3
                                                  if($2=="LOCATION:")   location=$3
                                                  if($2=="VERSION:")    version=$3
                                                  if($1=="")            print name,version,location
                                                }' > $WORKDIR/sbolist_${SBOKEY}
        fi
        cat $WORKDIR/sbolist_${SBOKEY}|awk '{print "SBO_'$SBOKEY' "$1" "$2" sbo '$SBOKEY' "$1"-"$2"-sbo-'$SBOKEY' "$3}'|sed "s,\./,./SBO_$SBOKEY/," >> $TMPDIR/pkglist.sbo
      done
    fi

    if [ $(basename $1) = "MANIFEST.bz2" ];then
      rm -f $WORKDIR/*-filelist.gz 2>/dev/null
      if [ ! -s $2 ];then
        echo -n|bzip2 -c >$2
      fi
    fi

    if [ $(basename $1) = "PACKAGES.TXT" ];then
      [ ! -s $2 ]&&echo > $2
      sed -i -e "1i===== START REPO: $PREPO : URL:$URLFILE  =====" -e "\$a===== END REPO: $PREPO =====" $2
    fi

    if [ $(basename $1) = "CHECKSUMS.md5.asc" -a ! -e $TMPDIR/signaturedownloaded ];then
      if ! grep -q PGP ${TMPDIR}/CHECKSUMS.md5.asc 2>/dev/null;then
          echo >&2
          echo "                        !!! F A T A L !!!" >&2
          echo "    Official Slackware Repository FAILS the CHECKSUMS.md5.asc download" |tee -a $TMPDIR/fatal.log >&2
          echo "    The repository may be invalid and the process will be ABORTED."     |tee -a $TMPDIR/fatal.log >&2
          echo "    Please check your mirror and try again."                            |tee -a $TMPDIR/fatal.log >&2
          echo >&2
          echo "invalid" > ${TMPDIR}/CHECKSUMS.md5.asc
      fi
      mv ${TMPDIR}/CHECKSUMS.md5.asc ${TMPDIR}/CHECKSUMS.md5-slackware.asc
      cp ${TMPDIR}/CHECKSUMS.md5-slackware.asc ${TMPDIR}/CHECKSUMS.md5.asc
      echo "slackpkgplus repositories" >>${TMPDIR}/CHECKSUMS.md5.asc
      for PREPO in ${REPOPLUS[*]};do
        URLFILE=${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}CHECKSUMS.md5.asc
        if echo $URLFILE | grep -q "dir:/" ; then
          continue
        fi
        echo -n "SLACKPKGPLUS_$PREPO[MD5] " >> ${TMPDIR}/CHECKSUMS.md5.asc
        if echo $URLFILE | grep -q "^file://" ; then
          URLFILE=${URLFILE:6}
          if [ -f $URLFILE ];then
            [[ "$FLAG" == "-q" || ! "$WGETOPTS" =~ -q ]]&&echo -e "\tLinking $URLFILE"
            ln -s $URLFILE ${TMPDIR}/CHECKSUMS.md5-$PREPO.asc
            md5sum ${TMPDIR}/CHECKSUMS.md5-$PREPO.asc|awk '{print $1}' >> ${TMPDIR}/CHECKSUMS.md5.asc
          else
            echo -e "\tNot found $URLFILE"
            echo "invalid" >> ${TMPDIR}/CHECKSUMS.md5.asc
            false
          fi
          continue
        fi
        $DOWNLOADER ${TMPDIR}/CHECKSUMS.md5-$PREPO.asc $URLFILE
        if [ $? -eq 0 ];then
          md5sum ${TMPDIR}/CHECKSUMS.md5-$PREPO.asc|awk '{print $1}' >> ${TMPDIR}/CHECKSUMS.md5.asc
          continue
        fi
        $DOWNLOADER ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz.asc `echo $URLFILE|sed 's/\.asc$/.gz.asc/'`
        if [ $? -eq 0 ];then
          md5sum ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz.asc|awk '{print $1}' >> ${TMPDIR}/CHECKSUMS.md5.asc
          continue
        fi
        $DOWNLOADER ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz `echo $URLFILE|sed 's/\.asc$/.gz/'`
        if [ $? -eq 0 ];then
          md5sum ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz|awk '{print $1}' >> ${TMPDIR}/CHECKSUMS.md5.asc
          continue
        fi
        $DOWNLOADER ${TMPDIR}/CHECKSUMS.md5-$PREPO `echo $URLFILE|sed 's/\.asc$//'`
        if [ $? -eq 0 ];then
          md5sum ${TMPDIR}/CHECKSUMS.md5-$PREPO|awk '{print $1}' >> ${TMPDIR}/CHECKSUMS.md5.asc
          continue
        fi
        echo "invalid" >> ${TMPDIR}/CHECKSUMS.md5.asc
      done
      touch $TMPDIR/signaturedownloaded
    fi
    if [ $(basename $1) = "ChangeLog.txt" ];then

      # ChangeLog.txt from slackware and 3rd party repository are stored
      # into TMPDIR/ChangeLogs directory. This directory is automatically
      # moved into WORKDIR by function cleanup() unless when this function
      # is called in response to a CTRL+C
      #
      # see http://www.linuxquestions.org/questions/slackware-14/slackpkg-vs-third-party-package-repository-4175427364/page35.html#post5537830

      if ! grep -q "[a-z]" ${TMPDIR}/ChangeLog.txt 2>/dev/null;then
          echo >&2
          echo "                        !!! F A T A L !!!" >&2
          echo "    Official Slackware Repository FAILS the ChangeLog.txt download"     |tee -a $TMPDIR/fatal.log >&2
          echo "    The repository may be invalid and the process will be ABORTED."     |tee -a $TMPDIR/fatal.log >&2
          echo "    Please check your mirror and try again."                            |tee -a $TMPDIR/fatal.log >&2
          echo >&2
          echo "invalid" > ${TMPDIR}/ChangeLog.txt
      fi
      mkdir ${TMPDIR}/ChangeLogs

      # Copy slackware ChangeLog.txt into directory dedicated to changelogs...
      cat ${TMPDIR}/ChangeLog.txt > ${TMPDIR}/ChangeLogs/slackware.txt

      for PREPO in ${REPOPLUS[*]}; do
        BASEDIR=${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]%}
        CLOGNAM=$PREPO.txt

        if echo $BASEDIR | grep -q "dir:/" ; then
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
            if [ -e $URLFILE ];then
              [[ "$FLAG" == "-q" || ! "$WGETOPTS" =~ -q ]]&&echo -e "\tLinking $URLFILE"
              ln -s $URLFILE ${TMPDIR}/$CLOGNAM
            fi
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
          cat ${TMPDIR}/$CLOGNAM >> ${TMPDIR}/ChangeLogs/$CLOGNAM
        else
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
    fi
    if [ $(basename $1) = "CHECKSUMS.md5" ];then
      if ! grep -q "[a-z]" ${TMPDIR}/CHECKSUMS.md5 2>/dev/null;then
          echo >&2
          echo "                        !!! F A T A L !!!" >&2
          echo "    Official Slackware Repository FAILS the CHECKSUMS.md5 download"     |tee -a $TMPDIR/fatal.log >&2
          echo "    The repository may be invalid and the process will be ABORTED."     |tee -a $TMPDIR/fatal.log >&2
          echo "    Please check your mirror and try again."                            |tee -a $TMPDIR/fatal.log >&2
          echo >&2
          echo "invalid" > ${TMPDIR}/CHECKSUMS.md5
      fi
      for PREPO in ${REPOPLUS[*]};do
        URLFILE=${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}CHECKSUMS.md5
        if echo $URLFILE | grep -q "^file://" ; then
          URLFILE=${URLFILE:6}
          if [ -f $URLFILE ];then
            [[ "$FLAG" == "-q" || ! "$WGETOPTS" =~ -q ]]&&echo -e "\tLinking $URLFILE"
            ln -s $URLFILE ${TMPDIR}/CHECKSUMS.md5-$PREPO
          else
            echo -e "\tNot found $URLFILE"
            false
          fi
        elif echo $URLFILE | grep -q "^dir:/" ; then
          touch ${TMPDIR}/CHECKSUMS.md5-$PREPO
          continue
        elif echo $URLFILE | grep -q -e "^httpdir://" -e "^httpsdir://" -e "^ftpdir://" ; then
          if [ "$CACHEUPDATE" == "on" ];then
            printf "    File: %-20s -> %-20s .. Downloading...\n" "$PREPO" "CHECKSUMS.md5"
            lftp $(echo ${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}|sed 's/dir//') -e "ls;quit" 2>/dev/null|awk '{print $NF}'|grep -E '^.*-[^-]+-[^-]+-[^\.]+\.t.z$'|sort -rn| \
              awk '{print "00000000000000000000000000000000  ./"$NF}' > ${TMPDIR}/CHECKSUMS.md5-$PREPO
          else
            lftp $(echo ${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}|sed 's/dir//') -e "ls;quit" |awk '{print $NF}'|grep -E '^.*-[^-]+-[^-]+-[^\.]+\.t.z$'|sort -rn| \
              awk '{print "00000000000000000000000000000000  ./"$NF}' > ${TMPDIR}/CHECKSUMS.md5-$PREPO
          fi
        else
          if [ -e ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz.asc ];then
            $DOWNLOADER ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz ${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}CHECKSUMS.md5.gz
            zcat ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz >${TMPDIR}/CHECKSUMS.md5-$PREPO
          else
            $DOWNLOADER ${TMPDIR}/CHECKSUMS.md5-$PREPO ${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}CHECKSUMS.md5
          fi
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
        fi

      done
      if [ "$TAG_PRIORITY" == "on" ];then
        for PREPO in ${PRIORITY[*]};do
          grep " \./$PREPO/" ${TMPDIR}/CHECKSUMS.md5 >> ${TMPDIR}/CHECKSUMS.md5-merged
        done
      else
        cp ${TMPDIR}/CHECKSUMS.md5 ${TMPDIR}/CHECKSUMS.md5-merged
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
        grep -E -e ^[a-f0-9]{32} ${TMPDIR}/CHECKSUMS.md5-$PREPO|grep -E -v -- "$FILTEREXCLUDE" |sed -r -e "s# \./# ./SLACKPKGPLUS_$PREPO/#" >> ${TMPDIR}/CHECKSUMS.md5-merged
      done
      if [ "$CHECKGPG" != "on" ];then
        mv ${TMPDIR}/CHECKSUMS.md5-merged ${TMPDIR}/CHECKSUMS.md5
      fi
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
          if [ -f $URLFILE ];then
            [[ "$FLAG" == "-q" || ! "$WGETOPTS" =~ -q ]]&&echo -e "\tLinking $URLFILE"
            ln -s $URLFILE $2-tmp-$PREPO
          else
            echo -e "\tNot found $URLFILE"
            false
          fi
        elif echo $URLFILE |grep -q "dir:/";then
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
          sleep 3
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
    local PREPO

    if echo $1|grep -E -q -e "/SLACKPKGPLUS_(file|dir|http|ftp|https)[0-9]" -e "/SBO_";then
      echo 1
      return
    fi
    if [ "$(basename $1)" == "CHECKSUMS.md5" ];then
      for PREPO in ${REPOPLUS[*]};do
        if [ -e ${TMPDIR}/CHECKSUMS.md5-$PREPO ];then
          if [ "$(checkgpg ${TMPDIR}/CHECKSUMS.md5-$PREPO)" == "0" ];then
            echo >&2
            echo "                        !!! F A T A L !!!" >&2
            echo "    Repository '$PREPO' FAILS the CHECKSUMS.md5.gz signature check" >&2
            echo "    The file may be corrupted or the gpg key may be not valid." >&2
            echo "    Remember to import keys by launching 'slackpkg update gpg'." >&2
            echo >&2
            sleep 5
            echo "Repository '$PREPO' FAILS the CHECKSUMS.md5 signature check." >> $TMPDIR/error.log
            echo "Try to run 'slackpkg update gpg' or disable the gpg check" >> $TMPDIR/error.log
            echo >> $TMPDIR/error.log
            echo 0
            return
          fi
        fi
        if [ -e ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz ];then
          if [ "$(checkgpg ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz)" == "0" ];then
            echo >&2
            echo "                        !!! F A T A L !!!" >&2
            echo "    Repository '$PREPO' FAILS the CHECKSUMS.md5 signature check" >&2
            echo "    The file may be corrupted or the gpg key may be not valid." >&2
            echo "    Remember to import keys by launching 'slackpkg update gpg'." >&2
            echo >&2
            sleep 5
            echo "Repository '$PREPO' FAILS the CHECKSUMS.md5.gz signature check." >> $TMPDIR/error.log
            echo "Try to run 'slackpkg update gpg' or disable the gpg check" >> $TMPDIR/error.log
            echo >> $TMPDIR/error.log
            echo 0
            return
          fi
        fi
      done
    fi
    if [ -e "${1}.asc" ];then

      FILENAME=$(basename ${1})
      if [ "$FILENAME" == "CHECKSUMS.md5" ];then
        REPO=slackware
        [ -e "${WORKDIR}/gpg/GPG-KEY-slackware64.gpg" ]&&REPO=slackware64
      elif [ ${FILENAME:0:13} == "CHECKSUMS.md5" ];then
        REPO=$(echo $FILENAME|cut -f2- -d-|sed 's/\.gz$//')
      else
        REPO=$(echo $1|sed -e "s,^/*$TEMP,/," -e "s,/\./,/,g" -e "s,//,/,g" -e "s,^/,," -e "s,/.*$,," -e "s,SLACKPKGPLUS_,,")
      fi

      if [ "$STRICTGPG" != "off" ] && ! echo ${MIRRORPLUS[$REPO]}|grep -q ^dir:/;then
        if [ ! -z "$REPO" ] && [ -e "${WORKDIR}/gpg/GPG-KEY-${REPO}.gpg" ] ; then
          gpg  --no-default-keyring \
               --keyring ${WORKDIR}/gpg/GPG-KEY-${REPO}.gpg \
               --verify ${1}.asc ${1} 2>/dev/null && echo "1" || echo "0"
        else
          echo "No matching GPG-KEY for repository '$REPO' checking $FILENAME" >&2
          echo "Try to run 'slackpkg update gpg' or disable gpg check" >&2
          echo "No matching GPG-KEY for repository '$REPO' checking $FILENAME" >>$TMPDIR/error.log
          echo "Try to run 'slackpkg update gpg' or disable gpg check" >>$TMPDIR/error.log
          echo 0
        fi
      else
        gpg --verify ${1}.asc ${1} 2>/dev/null && echo "1" || echo "0"
      fi
    else # $1.asc not downloaded
      echo 1
    fi
    if [ "$(basename $1)" == "CHECKSUMS.md5" ];then
      mv ${TMPDIR}/CHECKSUMS.md5-merged ${TMPDIR}/CHECKSUMS.md5
    fi
  } # END function checkgpg()

    # override slackpkg checkmd5()
    # Verify if the package was corrupted by checking md5sum
  function checkmd5() {
    local MD5ORIGINAL
    local MD5DOWNLOAD
    local PREPO
    local ARG

    if echo $1|grep -E -q -e "/SLACKPKGPLUS_(file|dir|http|ftp|https)[0-9]" -e "/SBO_";then
      echo 1
      return
    fi
    ARG=$(echo $1|sed "s|^/*$TEMP/||")
    PREPO=$(echo $ARG | cut -f2 -d/|sed 's/SLACKPKGPLUS_//' )
    if echo ${MIRRORPLUS[$PREPO]}|grep -q dir:/;then
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
    local ORIARGUMENT=$ARGUMENT
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

    [[ "${ORIARGUMENT}" =~ ,\*?$ ]]&&[[ "${ARGUMENT}" != "${ORIARGUMENT%,*}" ]]&&return
    ARGUMENT="${ARGUMENT%,*}"

    if [ -z "$TOPROCESS" ];then
      case "$CMD" in
        upgrade-all) TOPROCESS=$(comm -1 -2 ${TMPDIR}/lpkg ${TMPDIR}/dpkg | comm -1 -2 - ${TMPDIR}/spkg|wc -l);;
        install-new) TOPROCESS=$[$(awk -f /usr/libexec/slackpkg/install-new.awk ${WORKDIR}/ChangeLog.txt|sort -u|wc -l)+7];;
        install|upgrade|reinstall|download)
                     TOPROCESS=0
                     for TMPARGUMENT in $(echo $INPUTLIST); do
                       TOPROCESS=$[$TOPROCESS+$(grep -w -- "${TMPARGUMENT}" ${TMPDIR}/pkglist | cut -f2 -d\  | sort -u|wc -l)]
                     done
                     ;;
      esac
    fi
    if [ -z "$TOPROCESS" ];then
      let INPROGRESS++
      printf "%4s\b\b\b\b" "$INPROGRESS"
    else
      let INPROGRESS++
      printf "%3s%%\b\b\b\b" "$[$INPROGRESS*100/$TOPROCESS]"
    fi

    AUTOP=no
    if [[ "$CMD" == "upgrade" || "$CMD" == "upgrade-all" ]];then
      (
        ( cd $ROOT/ ; ls -1 ./var/log/packages/$ARGUMENT-*-*-* 2>/dev/null ) | awk -f /usr/libexec/slackpkg/pkglist.awk|grep -q " $ARGUMENT "
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
                  ( cd $ROOT/ ; ls -1 ./var/log/packages/$ARGUMENT-*-*-* 2>/dev/null ) | awk -f /usr/libexec/slackpkg/pkglist.awk|
                                              grep " $ARGUMENT "|awk '{print $2,$5}'|
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

            # The selected package is rejected when (1) no filter patterns were found, or (2)
            # none of the filter patterns matches the package's data
            #
          if [ ! -s ${TMPDIR}/filter.patterns ] \
                || \
                ! echo "${PKGDATA[*]}" | grep -q -f ${TMPDIR}/filter.patterns ;  then
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

    printf "%s\n" $ROOT/var/log/packages/* | awk -f /usr/libexec/slackpkg/pkglist.awk > ${TMPDIR}/tmplist
    sed -i 's/^^/:/' $TMPDIR/blacklist
    cat ${WORKDIR}/pkglist | applyblacklist > ${TMPDIR}/pkglist

    touch ${TMPDIR}/waiting
    echo -n "Looking for $PATTERN in package list. Please wait... "|tr -d '\\*'
    [ "$SPINNING" = "off" ] || spinning ${TMPDIR}/waiting &

    [ "$SENSITIVE_SEARCH" = "off" ] && GREPOPTS="--ignore-case"

    # -- PKGLIST:
    #      temporary file used to store data about handled packages. It uses
    #      the following format:
    #        repo:<repository_name>:bname:<package_basename>:ver:<package_version>:fname:<package_fullname>:
    #
    PKGLIST=$(tempfile --directory=$TMPDIR)
    PKGINFOS=$(tempfile --directory=$TMPDIR)

    PRITOPROCESS=${#PRIORITY[@]}
    PRIINPROGRESS=0
    for i in ${PRIORITY[@]}; do
      PRIPERCBASE=$[$PRIINPROGRESS*10000/$PRITOPROCESS]

      DIR="$i"
      PAT=""
      if [[ "$DIR" =~ ^[-_[:alnum:]]+[:] ]] ; then   # was  if echo "$DIR" | grep -q "[a-zA-Z0-9]\+[:]" ; then
        DIR=${i/:*/}                                 # was DIR=$(echo "$i" | cut -f1 -d":")

        # extract the pattern from $i, if and only if "$i" is to the syntax <repo>:<pattern>. Without
        # this, PAT would be set to $DIR when $i is to the syntax <repo>.
        #
        [[ "$i" =~ [:][[:alnum:]]+ ]] && PAT=${i/*:/}

        # when the current priority is of kind <REPO>:<PATTERN>, the loop must be short-circuited
        # when SEARCHSTR does not match PATTERN, otherwise, some packages could be mistakenly
        # selected.
        #
        # Example:
        #  - p7zip is present in alien and boost
        #  - alien has precedence over boost
        #  - PKGS_PRIORITY=(boost:infozip)
        #  - p7zip from alien is installed.
        #
        # In these case, the priority boost:infozip must be ignored otherwise slackpkg+ will
        # wrongly shows boost:p7zip as an upgrade for alien:p7zip
        #

        [ ! -z "$PAT" ] && ! echo "$SEARCHSTR" | grep  -qw "$PAT" && continue
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
        zgrep -E ${GREPOPTS} "${SEARCHSTR}" ${WORKDIR}/${DIR}-filelist.gz | \
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
        if [[ "${SEARCHSTR}" =~ ,\*?$ ]];then
          grep -h ${GREPOPTS} "^$DIR" ${TMPDIR}/pkglist ${TMPDIR}/pkglist-pre|grep -E ${GREPOPTS} "^[^ ]* ${SEARCHSTR%,*} " > $PKGINFOS
        else
          grep -h ${GREPOPTS} "^$DIR" ${TMPDIR}/pkglist ${TMPDIR}/pkglist-pre|grep -E ${GREPOPTS} "/SLACKPKGPLUS_$SEARCHSTR/|/$SEARCHSTR/|/$SEARCHSTR | [^ /]*$SEARCHSTR[^ /]* " > $PKGINFOS
        fi
      fi
      PKGTOPROCESS=$(cat $PKGINFOS|wc -l)
      PKGINPROGRES=0
      while read PKGDIR PKGBASENAME PKGVER PKGARCH PKGBUILD PKGFULLNAME PKGPATH PKGEXT ; do
        let PKGINPROGRES++

        printf "%3s%%\b\b\b\b" "$[$[$PRIPERCBASE+$PKGINPROGRES*10000/$PKGTOPROCESS/$PRITOPROCESS]/100]"

        # does nothing when the package has been handled ...
        grep ${GREPOPTS} -q "^repo:${PKGDIR}:bname:${PKGBASENAME}:ver:${PKGVER}:fname:${PKGFULLNAME}:" $PKGLIST && continue

        # When a package P' with the same basename has been handled before the current package, this means
        # the package P' has precedence over P.

        if grep ${GREPOPTS} -q ":bname:${PKGBASENAME}:" $PKGLIST ; then

             # P' has precedence over P. Therefore, P must be displayed with masked
             # attribute, unless when installed, in which case P' will be proposed
             # as an upgrade to P.

          MASKED=true

          if grep ${GREPOPTS} -q " $PKGFULLNAME " ${TMPDIR}/tmplist ; then
                COUNT=$(grep ":$PKGFULLNAME:" $PKGLIST | wc -l)

                # P is installed. It should not be masked. However, when different
                # repositories offer the same package (ie. same name,version,arch,
                # build) this rule must be applied only when there's *no occurence*
                # of fullname(P) in PKGLIST (ie. list of handled packages).
                #
                [ $COUNT -eq 0 ] && MASKED=false
          fi

          if [ $MASKED = true ] ; then
            LIST="$LIST MASKED_${PKGDIR}:${PKGFULLNAME}"
          fi
        else
          LIST="$LIST ${PKGDIR}:${PKGFULLNAME}"
        fi

        echo "repo:${PKGDIR}:bname:${PKGBASENAME}:ver:${PKGVER}:fname:${PKGFULLNAME}:" >> $PKGLIST

      done < $PKGINFOS
      let PRIINPROGRESS++
    done
    rm ${TMPDIR}/waiting
    rm -f $PKGLIST $PKGINFOS

    LIST=$( printf "%s\n" $LIST | applyblacklist | sort | uniq )

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

    {
    [ "$TERSESEARCH" == "off" ] && echo "[ Status#] [ Repository#] [ Package# ]"

    INSTPKGS="$(ls -f $ROOT/var/log/packages/)"

    c=0
    q=$(echo ${1}|wc -w)
    echo -n "Preparing list " >&2
    for i in $1; do
      let c++
      printf "%11s\b\b\b\b\b\b\b\b\b\b\b" "[$c/$q]" >&2
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
            if [ "${REPO}" = "SBo" ] ; then
                PKGLOCALNAMEVERSION=${CINSTPKG%-*-*}
                PKGREMOTENAMEVERSION=${RAWNAME%-*-*}
            else
                PKGLOCALNAMEVERSION=${CINSTPKG}
                PKGREMOTENAMEVERSION=${RAWNAME}
            fi

            if [ "${PKGLOCALNAMEVERSION}" = "${PKGREMOTENAMEVERSION}" ] ; then
              if [ "$TERSESEARCH" == "off" ];then
                echo "  installed#    $REPO#    $CINSTPKG"
              elif [ "$TERSESEARCH" == "tiny" ];then
                echo -e "[${c_inst}I${c_off}]#$REPO#:#$CINSTPKG"
              else
                echo -e "[${c_inst}inst${c_off}]#$REPO#:#$CINSTPKG"
              fi
            else

              INSTPKG_REPO=$(grep -m 1 " $CINSTPKG " ${WORKDIR}/pkglist | cut -f1 -d" " | sed "s/SLACKPKGPLUS_//")

              if [ ! -z "$INSTPKG_REPO" ] && [ "$INSTPKG_REPO" != "$REPO" ] ; then
                CINSTPKG="$INSTPKG_REPO:$CINSTPKG"
              fi

              if [ "$TERSESEARCH" == "off" ];then
                echo "  upgrade#    $REPO#    $CINSTPKG --> ${RAWNAME}"
              elif [ "$TERSESEARCH" == "tiny" ];then
                echo -e "[${c_upgr}U${c_off}]#$REPO#:#$CINSTPKG --> ${RAWNAME}"
              else
                echo -e "[${c_upgr}upgr${c_off}]#$REPO#:#$CINSTPKG --> ${RAWNAME}"
              fi

            fi
          fi
        done
      else
        if [ "$TERSESEARCH" == "off" ];then
          echo "  $STATUS#    $REPO#    ${RAWNAME}"
        elif [ "$TERSESEARCH" == "tiny" ];then
          echo -e "[$(echo $STATUS|sed -e "s/uninstalled(masked)/\\${c_mask}M\\${c_off}/" -e "s/uninstalled/\\${c_unin}-\\${c_off}/")]#$REPO#:#${RAWNAME}"
        else
          echo -e "[$(echo $STATUS|sed -e "s/uninstalled(masked)/\\${c_mask}mask\\${c_off}/" -e "s/uninstalled/\\${c_unin}unin\\${c_off}/")]#$REPO#:#${RAWNAME}"
        fi
      fi
    done|sort
    echo -en "\r" >&2
    }|column -t -s '#' -o ' '|( [[  "$CMD" == "search" ]]&&grep -E -i --color -e ^ -e "${PATTERN%,*}"||cat )
  } # END function searchlistEX()

    # Show detailed info for slackpkg info
    #
  function more_info(){
    echo
    cat $WORKDIR/pkglist|grep -E "^[^ ]* $NAME "|while read repository name version arch tag namepkg fullpath ext;do
      echo "Package:    $namepkg"
      echo "Repository: ${repository/SLACKPKGPLUS_/}"
      if echo $repository|grep -q SBO_;then
        fullpath=${fullpath/*$repository\//}
        if [ "$repository" == "SBO_current" ];then
          fullpath="plain/$fullpath/"
        else
          fullpath="$fullpath/"
        fi
        URLFILE=${SBO[${repository/SBO_}]%/}/$fullpath
        echo "Path:       ./${fullpath}"
        echo "Url:        ${URLFILE}"
      else
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
      q=$(echo $1|wc -w)
      c=1
      echo -n "Preparing list "
      if [ "$2" = "upgrade" ]; then
        ls -1 $ROOT/var/log/packages/ > $TMPDIR/tmplist
        for i in $1; do
          printf "%11s\b\b\b\b\b\b\b\b\b\b\b" "[$c/$q]"
          let c++
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
          printf "%11s\b\b\b\b\b\b\b\b\b\b\b" "[$c/$q]"
          let c++
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
      if [ "$2" != "remove" -a "$CHECKDISKSPACE" == "on" ];then
        COUNTLIST=$(echo $SHOWLIST|wc -w)
        compressed=0
        uncompressed=0
        n=0
        for i in $SHOWLIST;do
          let n++
          r=$(cat $TMPDIR/dialog.tmp|grep ^$i|cut -f2 -d'"')
          read c u <<<$(echo $(sed -e "1,/START REPO: $r :/d" -e "1,/ $i$/d" -e '/^$/Q' -e '/[^0-9][^ ][^K]$/d' -e 's/ K$//' $WORKDIR/PACKAGES.TXT|grep compressed|sort|awk '{print $NF}'))
          [ "$c" ]&&let compressed+=$c
          [ "$u" ]&&let uncompressed+=$u
          echo -en "Total space required to download $n/$COUNTLIST packages: $[$compressed/1024] MB \r"
        done
        available=$(df $TEMP|grep -v ^Filesystem|tail -1|awk '{print $4}')
        [ $compressed -lt 1024 ]&&toprint="$compressed KB"||toprint="$[$compressed/1024] MB"
        echo "Total space required to download: $toprint; Available: $[$available/1024] MB"
        if [ $available -lt $compressed ];then
          echo "No sufficient space to download packages. Do you want to continue anyway? (y/N)"
          answer
          if [ "$ANSWER" != "Y" ] && [ "$ANSWER" != "y" ]; then
            cleanup
          fi
        fi
        if [ "$2" == "install" ];then
          available=$(df $ROOT/usr|grep -v ^Filesystem|tail -1|awk '{print $4}')
          [ $uncompressed -lt 1024 ]&&toprint="$uncompressed KB"||toprint="$[$uncompressed/1024] MB"
          echo "Total space required to install: $toprint; Available: $[$available/1024] MB"
          if [ $available -lt $compressed ];then
            echo "No sufficient space to install packages. Do you want to continue anyway? (y/N)"
            answer
            if [ "$ANSWER" != "Y" ] && [ "$ANSWER" != "y" ]; then
              cleanup
            fi
          fi
        fi
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
      fi
    } # END function showlist()

  fi # (DIALOG=on/off)



  #### ===== END SHOWLIST FUNCTIONS ====== ######


  function debug(){
    echo "DEBUG $(date +%H:%M:%S.%N) (${BASH_LINENO[*]}): $@" >&2
  } # END function debug()



  ### =========================== MAIN ============================ ###


  SPINNING=off
  #if [ "$CMD" == "upgrade-all" ];then SPINNING=off ;fi

  export LC_ALL=C

  if [ "$DOWNLOADONLY" == "on" ];then
    DELALL=off
    DOWNLOAD_ALL=on
  fi

  if [ -z "$VERBOSE" ];then
    VERBOSE=1
  fi

  if [ ! -z "$ROOT" ];then
    echo "! ! ! FATAL ! ! !"
    echo
    echo "slackpkg+ does not support installation via \$ROOT"
    echo
    echo "please unset it"
    cleanup
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

  SPKGPLUS_VERSION="1.8.0"
  VERSION="$VERSION / slackpkg+ $SPKGPLUS_VERSION"
  
  if [ ${VERSION:0:4} == "2.82" ];then
    echo " ! ! ! WARNING ! ! ! "
    echo " You are using slackpkg+ $SPKGPLUS_VERSION release with Slackware 14.2"
    echo
    echo " It no longer supports Slackware 14.2 and should be used with"
    echo " Slackware current only."
    echo " Using it with Slackware 14.2 may no work properly"
    echo " Use slackpkg+ 1.7.0 instead"
    echo 
    SLPMIR="$(cat $CONF/slackpkgplus.conf|grep -E ^MIRRORPLUS.*slackpkg)"
    if [ "$SLPMIR" != "MIRRORPLUS['slackpkgplus']=https://slakfinder.org/slackpkg+1.7/" ];then
      echo " Please replace"
      cat $CONF/slackpkgplus.conf|grep -E ^MIRRORPLUS.*slackpkg
      echo " with"
      echo "MIRRORPLUS['slackpkgplus']=https://slakfinder.org/slackpkg+1.7/"
      echo " then run 'slackpkg update && slackpkg upgrade slackpkg+' to downgrade it"
      echo
      echo 
      echo -n "Do you want continue anyway? (Y/[N]) "
      read ANSW
      if [ "$ANSW" != "Y" ];then
        cleanup
      fi
    else
      echo " run 'slackpkg update && slackpkg upgrade slackpkg+' to downgrade it"
      echo
      sleep 5
    fi

  fi

  LINKVI=$(ls -L /usr/bin/vi 2>/dev/null)

  if [ ! -e "$WORKDIR" ];then
    mkdir -p "$WORKDIR"
  fi

  if [ -e ${WORKDIR}/current ]&&[ "$MIRROR_VERSION" != "current" ];then
    echo "WARNING:  ${WORKDIR}/current does exists and you have
          not selected slackware current repository.

          This may be you have an older version o slackpkg.
          You can continue anyway"|tee -a $TMPDIR/info.log
    echo
  fi
  if echo "${!MIRRORPLUS[@]}"|grep -wq multilib;then
    MULTILIB_ACTION="
          # slackpkg install multilib"
    MULTILIB_VERSION=$(echo ${MIRRORPLUS['multilib']}|sed -r -e 's,/+$,,' -e 's,.*/,,')
    if [ "$MULTILIB_VERSION" != "$MIRROR_VERSION" ];then
      echo "WARNING:    You have selected a mirror for Slackware $MIRROR_VERSION and a multilib
            repository for Slackware $MULTILIB_VERSION. This may damage your system.
            Please fix the configuration."|tee -a $TMPDIR/error.log
      echo
      sleep 5
    fi
  fi
  if [ "${SLACKWARE_VERSION:0:2}" == "14" ]&&[ "$MIRROR_VERSION" == "15.0" ];then
    echo "WARNING:  You have selected a mirror for Slackware 15.0 and you are running
          slackware $SLACKWARE_VERSION; if you are upgrading slackware be
          sure to run following steps:
          # slackpkg update
          # slackpkg install-new$MULTILIB_ACTION
          # slackpkg upgrade-all
          # slackpkg clean-system

          This message will disappear when the upgrade will finish"|tee -a $TMPDIR/info.log
    echo
    sleep 5
  elif [ "${MIRROR_VERSION:0:2}" == "14" ];then
    echo "FATAL:    You have selected a mirror for Slackware $MIRROR_VERSION!
          If this is an error please correct your slackpkg configuration.
          If you really wants to install Slackware $MIRROR_VERSION be sure
          to downgrade slackpkg+ to 1.7.0 since $SPKGPLUS_VERSION does not
          support Slackware $MIRROR_VERSION!"|tee -a $TMPDIR/fatal.log
    echo
    EXIT_CODE=1
    cleanup
  elif [ ! -e ${WORKDIR}/current ]&&[ -e ${WORKDIR}/currentplus ];then
    if [ "$SLACKWARE_VERSION" == "15.0+" ];then
      echo "WARNING:  You have changed the mirror from Slackware current to $MIRROR_VERSION;
          You are running Slackware $SLACKWARE_VERSION; this means a system DOWNGRADE!

          Be careful! If that's not what you want please check and fix your configuration!
      "|tee -a $TMPDIR/error.log
      sleep 5
    else
      echo "INFO:     You have changed the mirror from Slackware current to $MIRROR_VERSION;
          You are running Slackware $SLACKWARE_VERSION; if you are upgrading slackware be
          sure to run following steps:
          # slackpkg update
          # slackpkg install-new$MULTILIB_ACTION
          # slackpkg upgrade-all
          # slackpkg clean-system"|tee -a $TMPDIR/info.log
    fi
    echo
  elif [ -e ${WORKDIR}/current ]&&[ ! -e ${WORKDIR}/currentplus ];then
    echo "INFO:     You have changed the mirror to Slackware current;
          You are running Slackware $SLACKWARE_VERSION; if you are upgrading slackware be
          sure to run following steps:
          # slackpkg update
          # slackpkg install-new$MULTILIB_ACTION
          # slackpkg upgrade
          # slackpkg clean-system"|tee -a $TMPDIR/info.log
    echo
    sleep 5
  fi
  [ ! -e ${WORKDIR}/current ] && rm -f ${WORKDIR}/currentplus 2>/dev/null ||touch ${WORKDIR}/currentplus 2>/dev/null

  [ ! -s $WORKDIR/pkglist ] && rm -f $WORKDIR/CHECKSUMS.md5.asc
  if ! grep -q "slackpkgplus repositories" $WORKDIR/CHECKSUMS.md5.asc 2>/dev/null &&
       [ "$CMD" != "update" ] && [ "$CMD" != "new-config" ] && [ "$CMD" != "help" ];then
    echo "========================================================="
    echo "slackpkg was upgrades or slackpkg+ was temporary disabled"
    echo "We need to force 'slackpkg update' to re-enable slackpkg+"
    echo "Then you can re-run '$CMD' command                       "
    echo "========================================================="
    echo
    echo "slackpkg forced to rebuild pkglist database" >> $TMPDIR/info.log
    echo "Please may try 'slackpkg $CMD $INPUTLIST' now" >> $TMPDIR/info.log
    CMD="update"
  fi

  if [ ! -e $WORKDIR/install.log ];then
    touch $WORKDIR/install.log
  fi

  if [ -e $TEMP ]&&[ -z "$PURGECACHE" ];then
    # clean cache from packages without gpg signature
    find $TEMP ! -type d|sort|tac|awk '{if($1~/\.asc$/)f[$1]++;if($1~/\.t.z$/ && !f[$1".asc"])print $1}' |xargs -r rm -f
  fi

  #if [ "$UPARG" != "gpg" ]&&[ "$CHECKGPG" = "on" ]&&[ "$STRICTGPG" = "on" ] && ! ls -l $WORKDIR/gpg/GPG-KEY-slackware*.gpg >/dev/null 2>&1;then
  if [ "$UPARG" != "gpg" ]&&[ "$CHECKGPG" = "on" ]&&[ "$STRICTGPG" = "on" ];then
    ls -l $WORKDIR/gpg/GPG-KEY-slackware*.gpg >/dev/null 2>&1 || GPGFIRSTTIME=0
    for PREPO in "${!MIRRORPLUS[@]}" ; do
      if ! echo "${MIRRORPLUS[$PREPO]}"|grep -q -e "^dir:/" -e "^httpdir://" -e "^httpsdir://" -e "^ftpdir://" 2>/dev/null ; then
        ls -l $WORKDIR/gpg/GPG-KEY-${PREPO}.gpg >/dev/null 2>&1 || GPGFIRSTTIME=0
      fi
    done
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
  if [ ! -z "${REPOPLUS[*]}" ];then
    PRIORITY=( ${PRIORITY[*]} SLACKPKGPLUS_$(echo ${REPOPLUS[*]}|sed 's/ / SLACKPKGPLUS_/g') )
  fi

  # Test repositories
  for pp in ${REPOPLUS[*]};do
    echo "${MIRRORPLUS[$pp]}"|grep -q -e ^http:// -e ^https:// -e ^ftp:// -e ^file:// -e ^dir:/ -e ^httpdir:// -e ^httpsdir:// -e ^ftpdir://
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
    fi
  fi
  if [ "$CMD" == "update" ];then
    if [ $CONF/slackpkgplus.conf -nt $WORKDIR/CHECKSUMS.md5.asc ];then
      BATCH=on
      DEFAULT_ANSWER=Y
    fi
  fi
  if [ "$CMD" != "update" -a "$CMD" != "check-updates" ];then
    if [ $CONF/slackpkgplus.conf -nt $WORKDIR/CHECKSUMS.md5.asc ];then
      echo
      echo "NOTICE: remember to re-run 'slackpkg update' after modifying slackpkgplus.conf"
      echo
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

  if [ "$CMD" != "download" ];then
    internal_blacklist "^SBO_"
  fi

  if [ ! -z "$DOWNLOADCMD" ];then
    DOWNLOADER="$DOWNLOADCMD"
  else
    if [ "$VERBOSE" = "3" ];then
      DOWNLOADER="wgetdebug"
    else
      FLAG=""
      if [ "$CMD" = "update" ];then
        [ $VERBOSE -lt 2 ]&&FLAG="-nv"
        [ $VERBOSE -lt 2 ]&&[ "$CACHEUPDATE" = "on" ]&&FLAG="-q"
      else
        [ $VERBOSE -lt 1 ]&&FLAG="-nv"
      fi
      DOWNLOADER="wget $WGETOPTS --no-check-certificate $FLAG --passive-ftp -O"
    fi
  fi

  if [ "$CACHEUPDATE" == "on" ]&&[ "$CMD" == "update" -o "$CMD" == "check-updates" ];then
    CACHEDOWNLOADER=$DOWNLOADER
    CACHEDIR=$WORKDIR/cache
    mkdir -p $CACHEDIR
    find $CACHEDIR -mtime +30 -type f -exec rm -f {} \;
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

  if [ -e $TMPDIR/blacklist ];then
    sed -i 's/^/^/' $TMPDIR/blacklist
  fi
  if [ "$LEGACYBL" == "on" ];then
    BLKLOPT=-w
    grep -vE "(^#|^[[:blank:]]*$)" ${CONF}/blacklist > ${TMPDIR}/blacklist
  fi

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
      [[ "$pref" =~ , ]]&&{ pref="${pref/\*}" ; pref="${pref/,},*" ; }
      PRIORITY_FILTER_RULE=""

      # You can specify 'slackpkg install .' that is an alias of 'slackpkg install dir:./'
      if [ "$pref" == "." ];then
        pref="dir:./"
      fi

      # You can specify 'slackpkg install file:package-1.0-noarch-1my.txz' on local disk;
      # optionally you can add absolute or relative path.
      if echo "$pref" | grep -E -q "file:.*\.t.z$" ; then
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
      elif echo "$pref" | grep -E -q "^(https?|ftp)://.*/.*-[^-]+-[^-]+-[^\.]+\.t.z$" ;then
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
      elif echo "$pref" | grep -E -q "^(https?|ftp)://.*/.*" ;then
        repository=$(echo "$pref" | cut -f1 -d":")
        repository=$repository$(grep ^SLACKPKGPLUS_$repository[0-9] ${TMPDIR}/pkglist-pre|awk '{print $1}'|uniq|wc -l)
        lftp $pref -e "ls;quit" 2>/dev/null|awk '{print $NF}'|grep -E '^.*-[^-]+-[^-]+-[^\.]+\.t.z$'|sort -rn| \
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
            internal_blacklist "glibc-debug" # glibc-debug no longer exists but this not hurt
          elif [ "$CMD" == "remove" ] ; then
            internal_blacklist ".*_multilib-x86_64-.*" # slackpkg upgrade-all will remove it
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
    [[ "$PATTERN" =~ , ]]&&{ PATTERN="${PATTERN/\*}" ; PATTERN="${PATTERN/,}," ; }
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
        if [[ "${PATTERN}" =~ , ]];then
          SBORESULT="$(grep -E -i "^SBO_[^ ]* ${PATTERN%,*} " $WORKDIR/pkglist 2>/dev/null|awk '{print $6}')"
        else
          SBORESULT="$(grep -E -i "^SBO_[^ ]* [^ ]*${PATTERN}" $WORKDIR/pkglist 2>/dev/null|awk '{print $6}')"
        fi
        if [ ! -z "$SBORESULT" ];then
            SB=""
            for P in $SBORESULT ; do SB="$SB SLACKPKGPLUS_SBo:$P" ; done
            echo
            echo "Also found in SBo (download it with 'slackpkg download <package>'):"
            echo
            searchlistEX "$SB"
            echo
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
        #     checkchangelog() download the CHECKSUMS.md5.asc and stores it
        #     in ${TMPDIR}

        # extract the slackpkgplus repositories md5 from the CHECKSUMS.md5.asc
        # files (in ${WORKDIR} and ${TMPDIR} to identify updates in Slackware
        # repository.
        #
      grep -v "^SLACKPKGPLUS_.*\[MD5\] " ${WORKDIR}/CHECKSUMS.md5.asc > ${TMPDIR}/CHECKSUMS.md5.asc.old
      grep -v "^SLACKPKGPLUS_.*\[MD5\] " ${TMPDIR}/CHECKSUMS.md5.asc > ${TMPDIR}/CHECKSUMS.md5.asc.new
      
      if ! diff --brief ${TMPDIR}/CHECKSUMS.md5.asc.old ${TMPDIR}/CHECKSUMS.md5.asc.new >/dev/null ; then
              echo "slackware" > ${TMPDIR}/updated-repos.txt
      fi
      
        # -- get the list of the repositories configured before this call to check-updates
        #
      grep "^SLACKPKGPLUS_.*\[MD5\] " ${WORKDIR}/CHECKSUMS.md5.asc | sed 's/^SLACKPKGPLUS_//; s/\[MD5\]//' | cut -f1 -d" "> ${TMPDIR}/selected.3pr

        # create pseudo changelogs for the selected 3rd party repositories
        #
      grep "^SLACKPKGPLUS_.*\[MD5\] " ${WORKDIR}/CHECKSUMS.md5.asc | sort  > "${TMPDIR}/3rp-CHECKSUMS.old"
      grep "^SLACKPKGPLUS_.*\[MD5\] " ${TMPDIR}/CHECKSUMS.md5.asc | sort > "${TMPDIR}/3rp-CHECKSUMS.new"
      
        # from the pseudo checksums, find the updated 3rd party repositories and add them
        # to the updates report file
        #
      comm -1 -3  "${TMPDIR}/3rp-CHECKSUMS.old" \
                  "${TMPDIR}/3rp-CHECKSUMS.new" \
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
      echo "Slackpkg: Updated packages are available since last check." >&2
      EXIT_CODE=100
      
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
      echo "Slackpkg: No updated packages since last check."
      # Suppress the "pkglist is older than 24h" notice
      touch $WORKDIR/pkglist 2>/dev/null
    fi

    cleanup
  fi # "$CMD" == "check-updates"

  if [ "$CMD" == "download" ];then
    printf "%s\n" $ROOT/var/log/packages/* |
      awk -f /usr/libexec/slackpkg/pkglist.awk > ${TMPDIR}/tmplist

    cat $TMPDIR/pkglist-pre ${WORKDIR}/pkglist | applyblacklist > ${TMPDIR}/pkglist

    echo -n "Looking for $(echo $INPUTLIST | tr -d '\\*') in package list. Please wait... "
    for ARGUMENT in $(echo $INPUTLIST); do
      if [[ "$ARGUMENT" =~ , ]];then
        ARGUMENT=${ARGUMENT/\*} ; ARGUMENT=${ARGUMENT/,}
        for i in $(grep " ${ARGUMENT%,*} " ${TMPDIR}/pkglist | cut -f2 -d\  | sort -u); do
          LIST="$LIST $(grep " ${i} " ${TMPDIR}/pkglist |grep " ${ARGUMENT%,*} " | cut -f6,8 -d\  --output-delimiter=.)"
        done
      else
        for i in $(grep -w -- "${ARGUMENT}" ${TMPDIR}/pkglist | cut -f2 -d\  | sort -u); do
          LIST="$LIST $(grep " ${i} " ${TMPDIR}/pkglist |grep -w -- "${ARGUMENT}" | cut -f6,8 -d\  --output-delimiter=.)"
        done
      fi
      LIST="$(echo -e $LIST | sort -u)"
    done
    echo -e "DONE\n"
    DELALL="off"
    if ! [ "$LIST" = "" ]; then
      showlist "$LIST" $CMD
      for i in $SHOWLIST; do
        getpkg $i true
      done
    else
      echo -e "No packages match the pattern for download."
      EXIT_CODE=20
    fi
    cleanup
  fi

fi

INPROGRESS=0

