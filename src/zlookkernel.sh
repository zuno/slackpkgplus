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
  if [ "$KERNELMD5" != "$NEWKERNELMD5" ]; then
    KERNEL=$(readlink /boot/vmlinuz | sed 's/.*-\([1-9]\)/\1/')
    echo -e "\nYour kernel image was updated (found $KERNEL). You have to rebuild the bootloader.\nDo you want slackpkg to do it? (Y/n)"
    answer
    if [ "$ANSWER" != "n" ] && [ "$ANSWER" != "N" ]; then
      INITRD=/boot/initrd.gz
      if [ -e /boot/initrd-tree/command_line ];then
        OINITRD=$(cat /boot/initrd-tree/command_line|grep -- " -o "|sed -r 's/^.* -o *([^ ]*).*$/\1/')
        INITRD=${OINITRD:-$INITRD}

        if [ -f "$INITRD" ];then
          echo -en "Found $INITRD; rebuilding it with:\n  "
          MKINITRD=$(sed -e "s/ *-k *[^ ]\+//g" -e "s/ *$/ -k $KERNEL/" /boot/initrd-tree/command_line)
          echo "  $MKINITRD"
          echo "Do you want continue? (Y/n)"
          answer
          if [ "$ANSWER" != "n" ] && [ "$ANSWER" != "N" ]; then
            $MKINITRD
            if [ ! -d "/boot/initrd-tree/lib/modules/$KERNEL" ];then
              echo -e "\nWARNING! the initrd may failed to create\n"
              echo "  The initrd may failed to create." >>$TMPDIR/error.log
            fi
          fi
        fi
      fi


      if [ -e /boot/efi/EFI/Slackware/elilo.conf ];then
        echo -e "\nFound elilo. Copying files to EFI partition"
        COPYDONE=""
        for tocopy in vmlinuz vmlinuz-generic vmlinuz-huge `basename $INITRD`;do
          if [ -e /boot/$tocopy ]&&[ -e /boot/efi/EFI/Slackware/$tocopy ]&&grep -E -q "= *$tocopy *$" /boot/efi/EFI/Slackware/elilo.conf ;then
            echo "Do you want to copy $tocopy to EFI partition? (Y/n)"
            answer
            if [ "$ANSWER" != "n" ] && [ "$ANSWER" != "N" ]; then
              cp -v /boot/$tocopy /boot/efi/EFI/Slackware/$tocopy && COPYDONE="$COPYDONE $tocopy"
              touch -r /boot/$tocopy /boot/efi/EFI/Slackware/$tocopy
            fi
          fi
        done
        if [ -z "$COPYDONE" ];then
          echo -e "\nWARNING! no files copied. You have to fix bootloader yourself\n"
          echo "  No files copied to the EFI partition found. Fix it yourself" >>$TMPDIR/error.log
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
      elif [ -e /boot/grub ]&&[ -x /usr/sbin/grub-install ];then
        echo -e "\nWARNING! Grub found but not supported by slackpkg. You have to fix it yourself\n"
        echo "  Grub found but not supported by slackpkg. You have to fix it yourself" >>$TMPDIR/error.log
      else
        echo -e "\nWARNING! slackpkg can't found your bootloader configuration. You have to fix it yourself\n"
        echo "  slackpkg can't found your bootloader configuration. You have to fix it yourself" >>$TMPDIR/error.log
      fi
    fi
  fi
}
