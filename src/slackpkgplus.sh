# Thanks to AlienBob and phenixia2003 (on LQ) for contributing


declare -A MIRRORPLUS
if [ -e /etc/slackpkg/slackpkgplus.conf ];then
  . /etc/slackpkg/slackpkgplus.conf
fi

if [ "$SLACKPKGPLUS" = "on" ];then

  REPOPLUS=$(echo "${REPOPLUS[*]} ${PKGS_PRIORITY[*]} ${!MIRRORPLUS[*]}"|sed 's/ /\n/g'|sed 's/:.*//'|awk '{if(!a[$1]++)print $1}')
  PRIORITY=( ${PRIORITY[*]} slackpkgplus_$(echo $REPOPLUS|sed 's/ / slackpkgplus_/g') )
  
  # Test repositories
  for pp in ${REPOPLUS[*]};do
    echo "${MIRRORPLUS[$pp]}"|grep -q -e ^http:// -e ^https:// -e ^ftp:// -e ^file://
    if [ $? -ne 0 ];then
      echo "Repository '$pp' not configured." >> $TMPDIR/error.log
      echo "Add:" >> $TMPDIR/error.log
      echo "MIRRORPLUS['$pp']=http://repoaddres/..." >> $TMPDIR/error.log
      echo "See documentation in /usr/doc/slackpkg+-* for details" >> $TMPDIR/error.log
      cleanup
    fi
  done

  if [ /etc/slackpkgplus.conf -nt /var/lib/slackpkg/pkglist -a "$CMD" != "update" ];then
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
  if [ -z "$DOWNLOADER" ];then
    DOWNLOADER="wget --passive-ftp -O"
  fi

  function getfile(){
    local URLFILE
    URLFILE=$1

    if [ ${URLFILE:0:1} = "/" ];then
      URLFILE="file:/$URLFILE"
    fi
    if echo $URLFILE|grep -q /slackpkgplus_;then
      PREPO=$(echo $URLFILE|sed -r 's#^.*/slackpkgplus_([^/]+)/.*$#\1#')
      URLFILE=$(echo $URLFILE|sed "s#^.*/slackpkgplus_$PREPO/#${MIRRORPLUS[$PREPO]}#")
    fi
    
    if echo $URLFILE | grep -q "^file://" ; then
      URLFILE=${URLFILE:6}
      [ -f $URLFILE ] && cp -v $URLFILE $2
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
      if [ "$CHECKGPG" = "on" ];then
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
      else
	checkgpg ${TMPDIR}/CHECKSUMS.md5 >/dev/null
      fi
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

    # Global variable required by givepriority() 
    # 
  PRIORITYIDX=1
  
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
    
    grep "[[:digit:]]\+compat32[ ]" $WORKDIR/pkglist | cut -f2 -d" " | sort -u > $TMPDIR/available-compat32-packages.lst

    NEWCOMPAT32PKGS=$(comm -3 $TMPDIR/installed-compat32-packages.lst  $TMPDIR/available-compat32-packages.lst)
    
    if [ ! -z "$NEWCOMPAT32PKGS" ] ; then
      LIST=""
      
      for pkg in $NEWCOMPAT32PKGS ; do
	LIST="$LIST $(grep " ${pkg} " $WORKDIR/pkglist | cut -f6,8 -d" " --output-delimiter=".")"
      done
    fi
  fi
  
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
	
	if [ "$CMD" == "search" ] ; then
		# -- PKGLIST:
		#      temporary file used to store data about packages. It use
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
			
			grep "^${DIR}.*${PATTERN}" "${TMPDIR}/pkglist" > $PKGINFOS
						
			while read PKG ; do
				PKGDIR=$(echo "$PKG" | cut -f1 -d" ")
				PKGBASENAME=$(echo "$PKG" | cut -f2 -d" ")
				PKGFULLNAME=$(echo "$PKG" | cut -f6 -d" ")
				
				if echo "$PKGDIR" | grep -q "slackpkgplus_" ; then
					grep -q "^repository:${PKGDIR}:basename:${PKGBASENAME}:" $PKGLIST && continue
				else
					grep -q ":basename:${PKGBASENAME}:" $PKGLIST  && continue
				fi
				LIST="$LIST ${PKGDIR}:${PKGFULLNAME}"
				echo "repository:${PKGDIR}:basename:${PKGBASENAME}:" >> $PKGLIST				
			done < $PKGINFOS
		done
		
		rm -f $PKGLIST $PKGINFOS		
	fi

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
		
		if echo "$REPO" | grep -q "slackpkgplus_" ; then
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
	    INSTPKG=$(ls -1 /var/log/packages | \
		grep -e "^${BASENAME}-[^-]\+-\(${ARCH}\|fw\|noarch\)-[^-]\+")

		# INSTPKG is local version
		if [ ! "${INSTPKG}" = "" ]; then

			# If installed is it uptodate?
			if [ "${INSTPKG}" = "${RAWNAME}" ]; then
				STATUS=" installed "
				printf "  %-16s     %-24s     %-40s  \n" "$STATUS" "$REPO" "$INSTPKG"
			else
				STATUS="upgrade"
				printf "  %-16s     %-24s     %-40s  \n" "$STATUS" "$REPO" "$INSTPKG --> ${RAWNAME}"
			fi
		else
			printf "  %-16s     %-24s     %-40s  \n" "$STATUS" "$REPO" "${RAWNAME}"
		fi
	done
}
  
  if [ "$CMD" == "search" ] ; then
	PATTERN=$(echo $ARG | sed -e 's/\+/\\\+/g' -e 's/\./\\\./g' -e 's/ /\|/g')
	searchPackages $PATTERN

	if [ "$LIST" = "" ]; then
		echo -e "No package name matches the pattern."
	else
		echo -e "The list below shows all packages with name matching \"$PATTERN\".\n"
		searchlistEX "$LIST"
		
			# PENDING: file-search must be implemented first.
			#
		#echo -e "\nYou can search specific files using \"slackpkg file-search file\".\n"	
    fi
    cleanup
  fi
  
fi
