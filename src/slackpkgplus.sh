# Thanks to AlienBob and phenixia2003 (on LQ) for contributing


declare -A MIRRORPLUS
if [ -e /etc/slackpkg/slackpkgplus.conf ];then
  . /etc/slackpkg/slackpkgplus.conf
fi

if [ "$SLACKPKGPLUS" = "on" ];then

  REPOPLUS=${REPOPLUS[*]}
  PRIORITY=( ${PRIORITY[*]} slackpkgplus_$(echo $REPOPLUS|sed 's/ / slackpkgplus_/g') )
  

    # -- merge priorities from PKGS_PRIORITY with PRIORITY, as needed ...
  
  if [ ! -z "$PKGS_PRIORITY" -a "$CMD" != "update" ] ; then
    PREFIX=""
    
    for pp in ${PKGS_PRIORITY[*]} ; do
      repository=$(echo "$pp" | cut -f1 -d":")
      package=$(echo "$pp" | cut -f2- -d":")
    
      if [ ! -z "$repository" ] && [ ! -z "$package" ] ; then
	if [ -z "$PREFIX" ] ; then
	  PREFIX=( slackpkgplus_${repository}:$package )
	else
	  PREFIX=( ${PREFIX[*]} slackpkgplus_${repository}:$package )
	fi
      fi
    done
    
    [ ! -z "$PREFIX" ] && PRIORITY=( ${PREFIX[*]} ${PRIORITY[*]} )
  fi

  
  function checkgpg() {
    gpg --verify ${1}.asc ${1} 2>/dev/null && echo "1" || echo "0"
    if [ "$(basename $1)" == "CHECKSUMS.md5" ];then
      X86_64=$(ls /var/log/packages/aaa_base*x86_64*|head -1 2>/dev/null)
      for PREPO in $REPOPLUS;do
	if [ ! -z "$X86_64" ];then
	  egrep -e ^[a-f0-9]{32} ${TMPDIR}/CHECKSUMS.md5-$PREPO|egrep -- "-(x86_64|noarch)-" |sed -r "s# \./# ./slackpkgplus_$PREPO/#" >> ${TMPDIR}/CHECKSUMS.md5
	else
	  egrep -e ^[a-f0-9]{32} ${TMPDIR}/CHECKSUMS.md5-$PREPO|egrep -v -- "-(x86_64|arm)-" |sed -r "s# \./# ./slackpkgplus_$PREPO/#" >> ${TMPDIR}/CHECKSUMS.md5
	fi
      done
    fi
  }
  function getfile(){
    local URLFILE
    URLFILE=$1

    if echo $URLFILE|grep -q /slackpkgplus_;then
      PREPO=$(echo $URLFILE|sed -r 's#^.*/slackpkgplus_([^/]+)/.*$#\1#')
      URLFILE=$(echo $URLFILE|sed "s#^.*/slackpkgplus_$PREPO/#${MIRRORPLUS[$PREPO]}#")
    fi
    
    if echo $URLFILE | grep -q "^file://" ; then
      URLFILE=${URLFILE:6}
      cp -v $URLFILE $2
    else
      $DOWNLOADER $2 $URLFILE
    fi

    if [ $(basename $1) = "MANIFEST.bz2" ];then
      if [ ! -s $2 ];then
	echo -n|bzip2 -c >$2
      fi
    fi

    if [ $(basename $1) = "CHECKSUMS.md5" ];then
      for PREPO in $REPOPLUS;do
	URLFILE=${MIRRORPLUS[${PREPO/slackpkgplus_}]}CHECKSUMS.md5
	if echo $URLFILE | grep -q "^file://" ; then
	  URLFILE=${URLFILE:6}
	  cp -v $URLFILE $2-$PREPO
	else
	  $DOWNLOADER $2-$PREPO $URLFILE
	fi
      done
    fi

    if [ $(basename $1) = "CHECKSUMS.md5.asc" ];then
      for PREPO in $REPOPLUS;do
	URLFILE=${MIRRORPLUS[${PREPO/slackpkgplus_}]}CHECKSUMS.md5.asc
	if echo $URLFILE | grep -q "^file://" ; then
	  URLFILE=${URLFILE:6}
	  cp -v $URLFILE ${TMPDIR}/CHECKSUMS.md5-$PREPO.asc
	else
	  $DOWNLOADER ${TMPDIR}/CHECKSUMS.md5-$PREPO.asc $URLFILE
	fi
	if [ $? -eq 0 ];then
	  if [ $(checkgpg ${TMPDIR}/CHECKSUMS.md5-$PREPO) -ne 1 ];then
	    echo
	    echo "                        !!! F A T A L !!!"
	    echo "    Repository '$PREPO' FAILS to check CHECKSUMS.md5 signature"
	    echo "    The file may be corrupted or the gpg key may be not valid."
	    echo "    Remember to import keys launching 'slackpkg update gpg'."
	    echo
	    sleep 5
	    echo > ${TMPDIR}/CHECKSUMS.md5
	  fi
	else
	  echo
	  echo "                   !!! W A R N I N G !!!"
	  echo "    Repository '$PREPO' does NOT supports signature checking"
	  echo "    You SHOULD to disable GPG check by setting 'CHECKGPG=off'"
	  echo "    in /etc/slackpkg/slackpkg.conf"
	  echo
	  sleep 5
	fi
      done
    fi
    if [ $(basename $1) = "ChangeLog.txt" ];then
      for PREPO in $REPOPLUS;do
        # Not all repositories have the ChangeLog.txt, so I use md5 of PACKAGES.TXT instead
	URLFILE=${MIRRORPLUS[${PREPO/slackpkgplus_}]}PACKAGES.TXT
	if echo $URLFILE | grep -q "^file://" ; then
	  URLFILE=${URLFILE:6}
	  cp -v $URLFILE $2-tmp
	else
	  $DOWNLOADER $2-tmp ${MIRRORPLUS[${PREPO/slackpkgplus_}]}PACKAGES.TXT
	fi
	echo $PREPO $(md5sum $2-tmp|awk '{print $1}') >>$2
	rm $2-tmp
      done
    fi
    if [ $(basename $1) = "GPG-KEY" ];then
      for PREPO in $REPOPLUS;do
	URLFILE=${MIRRORPLUS[${PREPO/slackpkgplus_}]}GPG-KEY
	if echo $URLFILE | grep -q "^file://" ; then
	  URLFILE=${URLFILE:6}
	  cp -v $URLFILE $2-tmp
	else
	  $DOWNLOADER $2-tmp ${MIRRORPLUS[${PREPO/slackpkgplus_}]}GPG-KEY
        fi
	if [ $? -eq 0 ];then
	  gpg --import $2-tmp
	else
	  echo 
	  echo "                   !!! W A R N I N G !!!"
	  echo "    Repository '$PREPO' does NOT contains the GPG-KEY"
	  echo "    You SHOULD to disable GPG check by setting 'CHECKGPG=off'"
	  echo "    in /etc/slackpkg/slackpkg.conf"
	  echo
	  sleep 5
	fi
	rm $2-tmp
      done
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
		  

		    if echo "$ARGUMENT" | grep -q "$PAT" ; then
		      PKGDATA=( $(grep "^${DIR} ${ARGUMENT} " ${TMPDIR}/pkglist) )
			
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

  if [ "$CMD" == "install" ] || [ "$CMD" == "upgrade" ] ; then

	  NEWINPUTLIST=""

	  for pref in $INPUTLIST ; do
		  if echo "$pref" | grep -q "[a-zA-Z0-9]\+[:][a-zA-Z0-9]\+" ; then
			  repository=$(echo "$pref" | cut -f1 -d":")
			  package=$(echo "$pref" | cut -f2- -d":")

			  PRIORITY=( slackpkgplus_${repository}:$package ${PRIORITY[*]} )
		  else
			  package=$pref
		  fi
		  
		  NEWINPUTLIST="$NEWINPUTLIST $package"
	  done

	  INPUTLIST=$NEWINPUTLIST
	  
  fi

  if [ "$CMD" == "install-new" ] ; then 
    ls -1 /var/log/packages/*compat32 2>/dev/null | rev | cut -f1 -d/ | cut -f4- -d- | rev | sort > $TMPDIR/installed-compat32-packages.lst
    
    grep "[[:digit:]]\+compat32[ ]" $WORKDIR/pkglist | cut -f2 -d" " | sort > $TMPDIR/available-compat32-packages.lst

    NEWCOMPAT32PKGS=$(comm -3 $TMPDIR/installed-compat32-packages.lst  $TMPDIR/available-compat32-packages.lst)
    
    if [ ! -z "$NEWCOMPAT32PKGS" ] ; then
      LIST=""
      
      for pkg in $NEWCOMPAT32PKGS ; do
	LIST="$LIST $(grep " ${pkg} " $WORKDIR/pkglist | cut -f6,8 -d" " --output-delimiter=".")"
      done
    fi
  fi
  
fi
