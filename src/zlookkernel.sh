### Note about ZLookKernel ##
#
#
# After a kernel update, it try to rebuild the initrd - if any - and try to
# reinstall lilo/elilo
#
# To install it run (as root):
# $ ln -sf /usr/libexec/slackpkg/zlookkernel.sh /usr/libexec/slackpkg/functions.d/
#
# To uninstall it run (as root):
# $ rm /usr/libexec/slackpkg/functions.d/zlookkernel.sh
#

lookkernel() {
  NEWKERNELMD5=$(md5sum /boot/vmlinuz 2>/dev/null)
  [ "$KERNELMD5" = "$NEWKERNELMD5" ]&&return

  KERNEL=$(readlink -f /boot/vmlinuz | sed 's/.*-\([1-9]\)/\1/'| sed 's/-smp//')

  echo -e "\nYour kernel image was updated (found $KERNEL). You have to rebuild the bootloader.\nDo you want slackpkg to do it? (Y/n)"
  answer

  if [ "$ANSWER" = "n" ] || [ "$ANSWER" = "N" ]; then return;fi

  zgrep -q CONFIG_EXT4_FS=y /proc/config.gz && KTYPE=huge || KTYPE=generic
  zgrep -q 'CONFIG_LOCALVERSION="-smp"' /proc/config.gz && KSMP="-smp" || KSMP=""

  INITRD=/boot/initrd.gz
  if [ -r /boot/initrd-tree/command_line ];then
    OINITRD=$(cat /boot/initrd-tree/command_line|grep -- " -o "|sed -r 's/^.* -o *([^ ]*).*$/\1/')
    INITRD=${OINITRD:-$INITRD}
  fi

  if [ -r "$INITRD" ];then
    echo -en "Found $INITRD; rebuilding it with:\n  "
    MKINITRD=$(sed -e "s/ *-k *[^ ]\+//g" -e "s/ *$/ -k $KERNEL$KSMP/" /boot/initrd-tree/command_line)
    echo "  $MKINITRD"
    echo "Do you want continue? (Y/n)"
    answer
    if [ "$ANSWER" != "n" ] && [ "$ANSWER" != "N" ]; then
      $MKINITRD
      if [ ! -d "/boot/initrd-tree/lib/modules/$KERNEL$KSMP" ];then
        echo -e "\nWARNING! the initrd may failed to create\n"
        echo "You may retry by using mkinitrd_command_generator.sh:"
        /usr/share/mkinitrd/mkinitrd_command_generator.sh -k $KERNEL$KSMP -a "-o $INITRD" -r
        echo "Do you want to retry by using mkinitrd_command_generator.sh now? (Y/n)"
        answer
        if [ "$ANSWER" != "n" ] && [ "$ANSWER" != "N" ]; then
          /usr/share/mkinitrd/mkinitrd_command_generator.sh -k $KERNEL$KSMP -a "-o $INITRD" -r
          if [ ! -d "/boot/initrd-tree/lib/modules/$KERNEL$KSMP" ];then
            echo -e "\nWARNING! the initrd may failed to create\n"
            echo "  The initrd may failed to create." >>$TMPDIR/error.log
            if [ -e /usr/sbin/geninitrd ];then
              echo "  Try to run /usr/sbin/geninitrd to fix."
            fi
          fi
        else
          echo "  The initrd may failed to create." >>$TMPDIR/error.log
            if [ -e /usr/sbin/geninitrd ];then
              echo "  Try to run /usr/sbin/geninitrd to fix."
            fi
        fi
      fi
    fi
  fi



  if [ -r /boot/efi/EFI/Slackware/elilo.conf ];then
    ERRS=0
    echo -e "\nFound elilo. Do you want to copy files to EFI partition (Y/n)"
    answer
    if [ "$ANSWER" = "n" ] || [ "$ANSWER" = "N" ]; then return;fi

    if [ ! -r /boot/efi/EFI/Slackware/vmlinuz ] || ! grep -E -q "= *vmlinuz *$" /boot/efi/EFI/Slackware/elilo.conf ||
       [ ! -r /boot/efi/EFI/Slackware/elilo.efi ] || [ ! -r /boot/elilo-x86_64.efi ] || [ ! -r /boot/vmlinuz-$KTYPE$SMP ];then
        echo -e "\nWARNING! this is a non standard or invalid EFI installation\n  Try to run /usr/sbin/eliloconfig yourself to fix\n"
        echo -e "  Unable to fix EFI bootloader" >>$TMPDIR/error.log
        return
    fi
    if grep -E -q "initrd *=" /boot/efi/EFI/Slackware/elilo.conf;then
      if ! grep -E -q "initrd *= *initrd.gz *$" /boot/efi/EFI/Slackware/elilo.conf || [ $INITRD != /boot/initrd.gz ] ||
       [ ! -e /boot/efi/EFI/Slackware/initrd.gz ] || ! grep -E -q "= *initrd.gz *$" /boot/efi/EFI/Slackware/elilo.conf ||
       [ ! -r /boot/initrd.gz ];then
        echo -e "\nWARNING! this is a non standard or invalid EFI installation"
        echo -e "  Try to regenerate yourself the initrd, then run /usr/sbin/eliloconfig to fix\n"
        echo -e "  Unable to fix EFI bootloader" >>$TMPDIR/error.log
        return
      fi
      cp -v /boot/initrd.gz /boot/efi/EFI/Slackware/initrd.gz || ERRS=1
      touch -r /boot/initrd.gz /boot/efi/EFI/Slackware/initrd.gz
    fi
    cp -v /boot/vmlinuz-$KTYPE$SMP /boot/efi/EFI/Slackware/vmlinuz || ERRS=1
    touch -r /boot/vmlinuz-$KTYPE$SMP /boot/efi/EFI/Slackware/vmlinuz
    cp -v /boot/elilo-x86_64.efi /boot/efi/EFI/Slackware/elilo.efi || ERRS=1
    touch -r /boot/elilo-x86_64.efi /boot/efi/EFI/Slackware/elilo.efi

    if [ $ERRS -ne 0 ];then
      echo -e "\nWARNING! some error copying files. You have to fix bootloader yourself\n  Try to run /usr/sbin/eliloconfig yourself to fix"
      echo -e "Errors copying files to EFI partition. Fix it yourself" >>$TMPDIR/error.log
      return
    fi
  elif [ -x /sbin/lilo ]&&[ -e /etc/lilo.conf ]; then
    echo -e "\nFound lilo. Do you want to run now: /sbin/lilo ? (Y/n)"
    answer
    if [ "$ANSWER" != "n" ] && [ "$ANSWER" != "N" ]; then
      if ! /sbin/lilo -t ;then
        echo "You need to fix your lilo configuration. Then press return to continue."
        read
      fi
      /sbin/lilo -v
    fi
  elif [ -d /boot/grub ]&&[ -x /usr/sbin/grub-install ];then
    echo -e "\nWARNING! Grub found but not supported by slackpkg. You have to fix it yourself\n"
    echo "  Grub found but not supported by slackpkg. You have to fix it yourself" >>$TMPDIR/error.log
  else
    echo -e "\nWARNING! slackpkg can't found your bootloader configuration. You have to fix it yourself\n"
    echo "  slackpkg can't found your bootloader configuration. You have to fix it yourself" >>$TMPDIR/error.log
  fi
}
