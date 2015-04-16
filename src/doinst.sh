config() {
  NEW="$1"
  OLD="$(dirname $NEW)/$(basename $NEW .new)"
  # If there's no config file by that name, mv it over:
  if [ ! -r $OLD ]; then
    mv $NEW $OLD
  elif [ "$(cat $OLD | md5sum)" = "$(cat $NEW | md5sum)" ]; then # toss the redundant copy
    rm $NEW
  fi
  # Otherwise, we leave the .new copy for the admin to consider...
}

renam() {
  FILE="$1"
  if [ -r $FILE ]; then
    mv $FILE $FILE.tmp
  fi
}

copy_config_file() {
  ARCH=$(uname -m)
  case $ARCH in
    i386|i486|i586|i686)
      SRCMIRROR=slackpkgplus.x86.sample
    ;;
    x86-64|x86_64|X86-64|X86_64)
      SRCMIRROR=slackpkgplus.x86_64.sample
    ;;
    *)
      SRCMIRROR=slackpkgplus.x86.sample
    ;;
  esac
  cp usr/doc/slackpkg+-SLPVERSION/$SRCMIRROR etc/slackpkg/slackpkgplus.conf.new
  cat usr/doc/slackpkg+-SLPVERSION/repositories.txt |grep '^> ' |sed 's/^> /#/' >> etc/slackpkg/slackpkgplus.conf.new
}

copy_config_file
config etc/slackpkg/slackpkgplus.conf.new
config etc/slackpkg/greylist.new
config etc/slackpkg/notifymsg.conf.new
renam var/lib/slackpkg/ChangeLog.txt
renam var/lib/slackpkg/pkglist

echo
echo
echo "Please, read the README file before using slackpkg+"
echo
echo "Now you must rerun 'slackpkg update'"
echo

