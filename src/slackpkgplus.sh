# Thanks to AlienBob and phenixia2003 (on LQ) for contributing
# A special thanks to all packagers that make slackpkg+ useful


declare -A MIRRORPLUS
if [ -e /etc/slackpkg/slackpkgplus.conf ];then
  # You can override SLACKPKGPLUS VERBOSE USEBL from command-line
  EXTSLACKPKGPLUS=$SLACKPKGPLUS
  EXTVERBOSE=$VERBOSE
  EXTUSEBL=$USEBL

  . /etc/slackpkg/slackpkgplus.conf

  SLACKPKGPLUS=${EXTSLACKPKGPLUS:-$SLACKPKGPLUS}
  VERBOSE=${EXTVERBOSE:-$VERBOSE}
  USEBL=${EXTUSEBL:-$USEBL}

  USEBLACKLIST=true
  if [ "$USEBL" == "0" ];then
    USEBLACKLIST=false
  fi
fi

if [ "$SLACKPKGPLUS" = "on" ];then

  if [ ! -e "$WORKDIR" ];then
    mkdir -p "$WORKDIR"
  fi

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
      if [ "`basename $URLFILE`" != "MANIFEST.bz2" ];then
	echo -e "`basename $URLFILE`:\tdownload error" >> $TMPDIR/error.log
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

    if [ $(basename $1) = "MANIFEST.bz2" ];then
      if [ ! -s $2 ];then
        echo -n|bzip2 -c >$2
      fi
    fi

    if [ $(basename $1) = "CHECKSUMS.md5.asc" ];then
      if [ "$CHECKGPG" = "on" ];then
        for PREPO in $REPOPLUS;do
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
		$DOWNLOADER ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz $URLFILE.gz
		if [ $(checkgpg ${TMPDIR}/CHECKSUMS.md5-$PREPO.gz) -eq 0 ];then
		  echo
		  echo "                   !!! N O T I C E !!!"
		  echo "    Repository '$PREPO' does support signature checking for"
		  echo "    CHECKSUMS.md5 file, so the repository authenticity is guaranteed,"
		  echo "    but you MAY need to temporarily disable gpg check when you"
		  echo "    install the packages using:"
		  echo "    'slackpkg -checkgpg=off install packge'"
		  echo "    The package authenticity remains guaranteed."
		  echo
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
              echo > ${TMPDIR}/CHECKSUMS.md5
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
      for PREPO in $REPOPLUS;do
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
        echo $PREPO $(md5sum ${TMPDIR}/CHECKSUMS.md5-$PREPO|awk '{print $1}') >>$2
      done
    fi
    if [ $(basename $1) = "GPG-KEY" ];then
      for PREPO in $REPOPLUS;do
        if [ "${PREPO:0:4}" = "dir:" ];then
          continue
        fi
        URLFILE=${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}GPG-KEY
        if echo $URLFILE | grep -q "^file://" ; then
          URLFILE=${URLFILE:6}
          cp -v $URLFILE $2-tmp
        elif echo $URLFILE |grep -q "^dir:/";then
          continue
        else
          $DOWNLOADER $2-tmp ${MIRRORPLUS[${PREPO/SLACKPKGPLUS_}]}GPG-KEY
        fi
        if [ $? -eq 0 ];then
          gpg --import $2-tmp
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
        rm $2-tmp
      done
    fi
  }

  # override slackpkg checkgpg()
  # new checkgpg() is used to check gpg and to merge the CHECKSUMS.md5 files
  function checkgpg() {
    if echo $1|egrep -q "/SLACKPKGPLUS_(file|dir|http|ftp|https)[0-9]";then
      echo 1
      return
    fi
    if [ -e "${1}.asc" ];then
      gpg --verify ${1}.asc ${1} 2>/dev/null && echo "1" || echo "0"
    else
      echo 1
    fi
    if [ "$(basename $1)" == "CHECKSUMS.md5" ];then
      X86_64=$(ls /var/log/packages/aaa_base*x86_64*|head -1 2>/dev/null)
      for PREPO in $REPOPLUS;do
        if [ ! -z "$X86_64" ];then
          egrep -e ^[a-f0-9]{32} ${TMPDIR}/CHECKSUMS.md5-$PREPO|egrep -- "-(x86_64|noarch)-" |sed -r "s# \./# ./SLACKPKGPLUS_$PREPO/#" >> ${TMPDIR}/CHECKSUMS.md5
        else
          egrep -e ^[a-f0-9]{32} ${TMPDIR}/CHECKSUMS.md5-$PREPO|egrep -v -- "-(x86_64|arm)-" |sed -r "s# \./# ./SLACKPKGPLUS_$PREPO/#" >> ${TMPDIR}/CHECKSUMS.md5
        fi
      done
    fi
  }

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
  }

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
  function givepriority {
    local DIR
    local ARGUMENT=$1
    local PKGDATA
    local CPRIORITY
    local DIR
    local PKG

    unset NAME
    unset FULLNAME
    unset PKGDATA

    for CPRIORITY in ${PRIORITY[@]} ; do
      [ "$PKGDATA" ] && break

      if echo "$CPRIORITY " | grep -q "[a-zA-Z0-9]\+[:]" ; then
        DIR=$(echo "$CPRIORITY" | cut -f1 -d":")
        PAT=$(echo "$CPRIORITY" | cut -f2- -d":")

        # ARGUMENT is always a basename. But PAT can be:
        #   1. a regular expression (ie .*)
        #   2. a basename (openjdk)
        #   3. a partial (or complete) package name (vlc-2.0.6, ).
        #
        # The current "enhanced priority rule" is applied :
        #   + In case (1) and (2) when ARGUMENT contains the pattern PAT
        #   + In the case (3) when ARGUMENT starts the pattern PAT.
        #
        if echo "$ARGUMENT" | grep -q "$PAT" || echo "$PAT" | grep "^$ARGUMENT" ; then
          PKGDATA=""
          PKGINFOS=$(grep -n -m 1 "^${DIR} ${ARGUMENT} " ${TMPDIR}/pkglist)

          if [ ! -z "$PKGINFOS" ] ; then
            LINEIDX=$(echo "$PKGINFOS" | cut -f1 -d":")
              PKGDATA=( $(echo "$PKGINFOS" | cut -f2- -d":") )

              # -- move the line at #LINEIDX to #PRIORITYIDX and
              #    increment PRIORITYIDX
              #
              sed -i --expression "${LINEIDX}d" --expression "${PRIORITYIDX}i${PKGDATA[*]}" ${TMPDIR}/pkglist
              (( PRIORITYIDX++ ))
          fi
        fi
      else
        PKGDATA=( $(grep "^${CPRIORITY} ${ARGUMENT} " ${TMPDIR}/pkglist) )
      fi

      if [ "$PKGDATA" ]; then
        NAME=${PKGDATA[1]}
        FULLNAME=$(echo "${PKGDATA[5]}.${PKGDATA[7]}")
      fi
    done
  }

  function searchPackages() {
    local i

    INPUTLIST=$@

    grep -vE "(^#|^[[:blank:]]*$)" ${CONF}/blacklist > ${TMPDIR}/blacklist
    if echo $CMD | grep -q install ; then
      ls -1 /var/log/packages/* | awk -f /usr/libexec/slackpkg/pkglist.awk > ${TMPDIR}/tmplist
    else
      ls -1 /var/log/packages/* | awk -f /usr/libexec/slackpkg/pkglist.awk | applyblacklist > ${TMPDIR}/tmplist
    fi
    cat ${WORKDIR}/pkglist | applyblacklist > ${TMPDIR}/pkglist

    touch ${TMPDIR}/waiting

    # -- PKGLIST:
    #      temporary file used to store data about packages. It uses
    #      the following format:
    #        repository:<repository_name>:basename:<package_basename>:
    #
    PKGLIST=$(tempfile --directory=$TMPDIR)
    PKGINFOS=$(tempfile --directory=$TMPDIR)

    for i in ${PRIORITY[@]}; do
      DIR="$i"
      if echo "$DIR" | grep -q "[a-zA-Z0-9]\+[:]" ; then
              DIR=$(echo "$i" | cut -f2- -d":")
      fi

      if [ "$CMD" == "file-search" ] ; then
        [ ! -e "${WORKDIR}/${DIR}-filelist.gz" ] && continue

        # NOTE:
        #  The awk below produces an output formatted like
        #  in file TMPDIR/pkglist, but without true values
        #  for the fields: version(3) arch(4) build(5), path(7),
        #  extension(8)
        #
        zegrep -w "${INPUTLIST}" ${WORKDIR}/${DIR}-filelist.gz | \
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
        grep "^${DIR}.*${PATTERN}" "${TMPDIR}/pkglist" > $PKGINFOS
      fi

      while read PKG ; do
        PKGDIR=$(echo "$PKG" | cut -f1 -d" ")
        PKGBASENAME=$(echo "$PKG" | cut -f2 -d" ")
        PKGFULLNAME=$(echo "$PKG" | cut -f6 -d" ")

        if echo "$PKGDIR" | grep -q "SLACKPKGPLUS_" ; then
          grep -q "^repository:${PKGDIR}:basename:${PKGBASENAME}:" $PKGLIST && continue
        else
          grep -q ":basename:${PKGBASENAME}:" $PKGLIST  && continue
        fi
        LIST="$LIST ${PKGDIR}:${PKGFULLNAME}"
        echo "repository:${PKGDIR}:basename:${PKGBASENAME}:" >> $PKGLIST
      done < $PKGINFOS
    done
    rm -f $PKGLIST $PKGINFOS

    LIST=$(echo -e $LIST | tr \  "\n" | uniq )

    rm ${TMPDIR}/waiting

    echo -e "DONE\n"
  }

  function searchlistEX() {
    local i
    local BASENAME
    local RAWNAME
    local STATUS
    local INSTPKG
    local REPO
    local PNAME

    printf "[ %-16s ] [ %-24s ] [ %-40s ]\n" "Status" "Repository" "Package"
    for i in $1; do
      REPO=$(echo "$i" | cut -f1 -d":")
      PNAME=$(echo "$i" | cut -f2- -d":")

      if echo "$REPO" | grep -q "SLACKPKGPLUS_" ; then
        REPO=$(echo "$REPO" | cut -f2- -d"_")
      else
        REPO=""
      fi

      if [ -z "$REPO" ] && [ "$BASENAME" = "$(cutpkg ${PNAME})" ]; then
        continue
      fi

      # BASENAME is base package name
      BASENAME="$(cutpkg ${PNAME})"

      # RAWNAME is Latest available version
      RAWNAME="${PNAME/%.t[blxg]z/}"

      # Default is uninstalled
      STATUS="uninstalled"

      # First is the package already installed?
      # Amazing what a little sleep will do
      # exclusion is so much nicer :)
      INSTPKG=$(ls -1 /var/log/packages | grep -e "^${BASENAME}-[^-]\+-[^-]\+-[^-]\+")
      #INSTPKG=$(ls -1 /var/log/packages | grep -e "^${BASENAME}-[^-]\+-\(${ARCH}\|fw\|noarch\)-[^-]\+")

      # INSTPKG is local version
      if [ ! "${INSTPKG}" = "" ]; then

        # INSTPKG can contains more than one package. But only those
        # that match the basename ${BASENAME} must be handled

        for CINSTPKG in ${INSTPKG} ; do
          CBASENAME=$(echo "${CINSTPKG}" | rev | cut -f4- -d- | rev)

          if [ "${CBASENAME}" == "${BASENAME}" ] ; then

            # If installed is it uptodate?
            if [ "${CINSTPKG}" = "${RAWNAME}" ]; then
              STATUS=" installed "
              printf "  %-16s     %-24s     %-40s  \n" "$STATUS" "$REPO" "$CINSTPKG"
            else
              STATUS="upgrade"
              printf "  %-16s     %-24s     %-40s  \n" "$STATUS" "$REPO" "$CINSTPKG --> ${RAWNAME}"
            fi
          fi
        done
      else
        printf "  %-16s     %-24s     %-40s  \n" "$STATUS" "$REPO" "${RAWNAME}"
      fi
    done
  }

  REPOPLUS=$(echo "${REPOPLUS[*]} ${PKGS_PRIORITY[*]} ${!MIRRORPLUS[*]}"|sed 's/ /\n/g'|sed 's/:.*//'|awk '{if(!a[$1]++)print $1}')
  PRIORITY=( ${PRIORITY[*]} SLACKPKGPLUS_$(echo $REPOPLUS|sed 's/ / SLACKPKGPLUS_/g') )

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

  if [ /etc/slackpkgplus.conf -nt $WORKDIR/pkglist -a "$CMD" != "update" ];then
    echo
    echo "NOTICE: remember to re-run 'slackpkg update' after modifing slackpkgplus.conf"
    echo
    sleep 5
  fi

  # -- merge priorities from PKGS_PRIORITY with PRIORITY, as needed ...

  if [ ! -z "$PKGS_PRIORITY" -a "$CMD" != "update" ] ; then
    PREFIX=""

    for pp in ${PKGS_PRIORITY[*]} ; do
      repository=$(echo "$pp" | cut -f1 -d":")
      package=$(echo "$pp" | cut -f2- -d":")

      if [ ! -z "$repository" ] && [ ! -z "$package" ] ; then
        if [ -z "$PREFIX" ] ; then
          PREFIX=( SLACKPKGPLUS_${repository}:$package )
        else
          PREFIX=( ${PREFIX[*]} SLACKPKGPLUS_${repository}:$package )
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

  # Adds the pattern given by $(1) into the internal blacklist
  # ${TMPDIR}/blacklist.slackpkgplus
  #
  # ($1) The pattern to add.
  #
  function internal_blacklist() {
    echo "$1" >> ${TMPDIR}/blacklist.slackpkgplus
  }

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
    cat ${TMPDIR}/blacklist.tmp
    if [ "$(head -1 ${TMPDIR}/blacklist.tmp|awk '{print $1}')" != "local" ];then
      cat ${TMPDIR}/pkglist-pre
    fi

  }


  DOWNLOADER="wget --no-check-certificate --passive-ftp -O"
  if [ "$VERBOSE" = "0" ];then
    DOWNLOADER="wget --no-check-certificate -nv --passive-ftp -O"
  elif [ "$VERBOSE" = "2" ];then
    DOWNLOADER="wget --no-check-certificate --passive-ftp -O"
  elif [ "$CMD" = "update" ];then
    DOWNLOADER="wget --no-check-certificate -nv --passive-ftp -O"
  fi

  # Global variable required by givepriority()
  #
  PRIORITYIDX=1

  touch ${TMPDIR}/pkglist-pre
  for PREPO in $REPOPLUS;do
    pref=${MIRRORPLUS[$PREPO]}
    if [ "${pref:0:5}" = "dir:/" ];then
      localpath=$(echo "$pref" | cut -f2- -d":"|sed -e 's_/$__' -e 's_//_/_')
      MIRRORPLUS[$PREPO]="dir:$localpath/"
      if [ ! -d "$localpath" ];then
	continue
      fi
      ( cd $localpath
	ls -ld *.t[blxg]z|sort -rn|grep ^-|awk '{print "./SLACKPKGPLUS_'$PREPO'/"$NF}'|awk -f /usr/libexec/slackpkg/pkglist.awk >> ${TMPDIR}/pkglist-pre
      )
    fi
  done

  if [ "$CMD" == "install" ] || [ "$CMD" == "upgrade" ] || [ "$CMD" == "reinstall" ] || [ "$CMD" == "remove" ] ; then

    NEWINPUTLIST=""
    PRIORITYLIST=""

    for pref in $INPUTLIST ; do

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
	  ls -ld *.t[blxg]z|sort -rn|grep ^-|awk '{print "./SLACKPKGPLUS_'$repository'/"$NF}'|awk -f /usr/libexec/slackpkg/pkglist.awk >> ${TMPDIR}/pkglist-pre
	)
        MIRRORPLUS[$repository]="file:/$localpath/"
	PRIORITYLIST=( ${PRIORITYLIST[*]} SLACKPKGPLUS_${repository}:.* )
	REPOPLUS=( ${repository} ${REPOPLUS[*]} )
        package=SLACKPKGPLUS_$repository

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

      # You can specify 'slackpkg install reponame:packagename'
      elif echo "$pref" | grep -q "[a-zA-Z0-9]\+[:][a-zA-Z0-9]\+" ; then

        if [ "$CMD" == "install" ] || [ "$CMD" == "upgrade" ] ; then
          repository=$(echo "$pref" | cut -f1 -d":")
          package=$(echo "$pref" | cut -f2- -d":")

          PRIORITYLIST=( ${PRIORITYLIST[*]} SLACKPKGPLUS_${repository}:$package )
        fi

      # You can specify 'slackpkg install reponame' where reponame is a thirdy part repository
      elif grep -q "^SLACKPKGPLUS_${pref}[ ]" ${WORKDIR}/pkglist ${TMPDIR}/pkglist-pre ; then

        echo "$pref" | grep -qi "multilib" && MLREPO_SELELECTED=true

        if $MLREPO_SELELECTED && [ "$CMD" == "remove" ] ; then
          internal_blacklist "glibc"
          internal_blacklist "gcc"
        fi

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

      # You can specify 'slackpkg install argument' where argument is a package name, part of package name, directory name in repository
      else
        package=$pref
      fi

      if [ "$CMD" == "remove" ];then
	package=$(echo $package|sed 's/\.t[blxg]z$//')
      fi

      # -- only insert "package" if not in NEWINPUTLIST
      echo "$NEWINPUTLIST" | grep -qw "${package}" || NEWINPUTLIST="$NEWINPUTLIST $package"
    done

    INPUTLIST=$NEWINPUTLIST

    if [ ! -z "$PRIORITYLIST" ] ; then
      NEWPRIORITY=( ${PRIORITYLIST[*]} ${PRIORITY[*]} )
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
  fi


  if [ "$CMD" == "search" ] || [ "$CMD" == "file-search" ] ; then
    PATTERN=$(echo $ARG | sed -e 's/\+/\\\+/g' -e 's/\./\\\./g' -e 's/ /\|/g')
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
  fi

fi
