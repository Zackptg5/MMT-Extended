##########################################################################################
#
# MMT Extended Utility Functions
#
##########################################################################################

debug_log() {
  $BOOTMODE && local LOG=/storage/emulated/0/$MODID-debug || local LOG=/data/media/0/$MODID-debug
  set +x
  echo -e "***---Device Info---***" > $LOG-tmp.log
  echo -e "\n---Props---\n" >> $LOG-tmp.log
  getprop >> $LOG-tmp.log
  echo -e "\n\n***---Magisk Info---***" >> $LOG-tmp.log
  echo -e "\n---Magisk Version---\n\n$MAGISK_VER_CODE" >> $LOG-tmp.log
  echo -e "\n---Installed Modules---\n" >> $LOG-tmp.log
  ls $NVBASE/modules >> $LOG-tmp.log
  echo -e "\n---Last Magisk Log---\n" >> $LOG-tmp.log
  [ -d /cache ] && cat /cache/magisk.log >> $LOG-tmp.log || cat /data/cache/magisk.log >> $LOG-tmp.log
  echo -e "\n\n***---MMT Extended Debug Info---***" >> $LOG-tmp.log
  echo -e "\n---Installed Files---\n" >> $LOG-tmp.log
  grep "^+* cp_ch" $LOG.log | sed 's/.* //g' >> $LOG-tmp.log
  sed -i -e "\|$TMPDIR/|d" -e "\|$MODPATH|d" $LOG-tmp.log
  find $MODPATH -type f > $LOG-tmp.log
  echo -e "\n---Installed Boot Scripts---\n" >> $LOG-tmp.log
  grep "^+* install_script" $LOG.log | sed -e 's/.* //g' -e 's/^-.* //g' >> $LOG-tmp.log
  echo -e "\n---Installed Prop Files---\n" >> $LOG-tmp.log
  grep "^+* prop_process" $LOG.log | sed 's/.* //g' >> $LOG-tmp.log
  echo -e "\n---Shell & MMT Extended Variables---\n" >> $LOG-tmp.log
  (set) >> $LOG-tmp.log
  echo -e "\n---(Un)Install Log---\n" >> $LOG-tmp.log
  echo "$(cat $LOG.log)" >> $LOG-tmp.log
  mv -f $LOG-tmp.log $LOG.log
}

cleanup() {
  $BOOTMODE || { umount_apex; recovery_cleanup; }
  ui_print " "
  ui_print "    **************************************"
  ui_print "    *   MMT Extended by Zackptg5 @ XDA   *"
  ui_print "    **************************************"
  ui_print " "
  $DEBUG && debug_log
  rm -rf $TMPDIR 2>/dev/null
  exit 0
}

mount_apex() {
  [ ! -d /system/apex -o -e /apex/* ] && return 0
  # Mount apex files so dynamic linked stuff works
  [ -L /apex ] && rm -f /apex
  # Apex files present - needs to extract and mount the payload imgs
  if [ -f "/system/apex/com.android.runtime.release.apex" ]; then
    local j=0
    [ -e /dev/block/loop1 ] && local minorx=$(ls -l /dev/block/loop1 | awk '{print $6}') || local minorx=1
    for i in /system/apex/*.apex; do
      local DEST="/apex/$(basename $i | sed 's/.apex$//')"
      [ "$DEST" == "/apex/com.android.runtime.release" ] && DEST="/apex/com.android.runtime"
      mkdir -p $DEST
      unzip -qo $i apex_payload.img -d /apex
      mv -f /apex/apex_payload.img $DEST.img
      while [ $j -lt 100 ]; do
        local loop=/dev/loop$j
        mknod $loop b 7 $((j * minorx)) 2>/dev/null
        losetup $loop $DEST.img 2>/dev/null
        j=$((j + 1))
        losetup $loop | grep -q $DEST.img && break
      done;
      uloop="$uloop $((j - 1))"
      mount -t ext4 -o loop,noatime,ro $loop $DEST || return 1
    done
  # Already extracted payload imgs present, just mount the folders
  elif [ -d "/system/apex/com.android.runtime.release" ]; then
    for i in /system/apex/*; do
      local DEST="/apex/$(basename $i)"
      [ "$DEST" == "/apex/com.android.runtime.release" ] && DEST="/apex/com.android.runtime"
      mkdir -p $DEST
      mount -o bind,ro $i $DEST
    done
  fi
  touch /apex/mmt-ex
}

umount_apex() {
  [ -d /system/apex ] || return 0
  [ -f /apex/mmt-ex -o -f /apex/magtmp ] || return 0
  for i in /apex/*; do
    umount -l $i 2>/dev/null
  done
  if [ -f "/system/apex/com.android.runtime.release.apex" ]; then
    for i in $uloop; do
      local loop=/dev/loop$i
      losetup -d $loop 2>/dev/null || break
    done
  fi
  rm -rf /apex
}

# mount_part <partname> <flag>
mount_part() {
  local PART=$1
  local POINT=/${PART}
  local FLAG=$2
  [ -z $FLAG ] && FLAG=rw
  [ -L $POINT ] && rm -f $POINT
  mkdir $POINT 2>/dev/null
  is_mounted $POINT && return
  ui_print "- Mounting $PART"
  mount -o $FLAG $POINT 2>/dev/null
  if ! is_mounted $POINT; then
    local BLOCK=`find_block $PART$SLOT`
    mount -o $FLAG $BLOCK $POINT
  fi
  is_mounted $POINT || abort "! Cannot mount $POINT"
}

device_check() {
  local PROP=$(echo "$1" | tr '[:upper:]' '[:lower:]') i
  for i in /system_root /system /vendor /odm /product; do
    if [ -f $i/build.prop ]; then
      for j in "ro.product.device" "ro.build.product" "ro.product.vendor.device" "ro.vendor.product.device"; do
        [ "$(sed -n "s/^$j=//p" $i/build.prop 2>/dev/null | head -n 1 | tr '[:upper:]' '[:lower:]')" == "$PROP" ] && return 0
      done
    fi
  done
  return 1
}

run_addons() {
  local OPT=`getopt -o mhiuv -- "$@"` NAME PNAME
  eval set -- "$OPT"
  while true; do
    case "$1" in
      -m) NAME=main; shift;;
      -h) NAME=preinstall; PNAME="Preinstall"; shift;;
      -i) NAME=install; PNAME="Install"; shift;;
      -u) NAME=uninstall; PNAME="Uninstall"; shift;;
      -v) NAME=postuninstall; PNAME="Postuninstall"; shift;;
      --) shift; break;;
    esac
  done
  if [ "$(ls -A $MODPATH/common/addon/*/$NAME.sh 2>/dev/null)" ]; then
    [ -z $PNAME ] || { ui_print " "; ui_print "- Running $PNAME Addons -"; }
    for i in $MODPATH/common/addon/*/$NAME.sh; do
      ui_print "  Running $(echo $i | sed -r "s|$MODPATH/common/addon/(.*)/$NAME.sh|\1|")..."
      . $i
    done
    [ -z $PNAME ] || { ui_print " "; ui_print "- `echo $PNAME`ing (cont) -"; }
  fi
}

cp_ch() {
  local OPT=`getopt -o inr -- "$@"` BAK=true UBAK=true FOL=false
  eval set -- "$OPT"
  while true; do
    case "$1" in
      -n) UBAK=false; shift;;
      -r) FOL=true; shift;;
      --) shift; break;;
      *) abort "Invalid cp_ch argument $1! Aborting!";;
    esac
  done
  local SRC="$1" DEST="$2" OFILES="$1"
  $FOL && local OFILES=$(find $SRC -type f 2>/dev/null)
  [ -z $3 ] && PERM=0644 || PERM=$3
  case "$DEST" in
    $TMPDIR/*|$MODULEROOT/*|$NVBASE/modules/$MODID/*) BAK=false;;
  esac
  for OFILE in ${OFILES}; do
    if $FOL; then
      if [ "$(basename $SRC)" == "$(basename $DEST)" ]; then
        local FILE=$(echo $OFILE | sed "s|$SRC|$DEST|")
      else
        local FILE=$(echo $OFILE | sed "s|$SRC|$DEST/$(basename $SRC)|")
      fi
    else
      [ -d "$DEST" ] && local FILE="$DEST/$(basename $SRC)" || local FILE="$DEST"
    fi
    if $BAK && $UBAK; then
      [ ! "$(grep "$FILE$" $INFO 2>/dev/null)" ] && echo "$FILE" >> $INFO
      [ -f "$FILE" -a ! -f "$FILE~" ] && { mv -f $FILE $FILE~; echo "$FILE~" >> $INFO; }
    elif $BAK; then
      [ ! "$(grep "$FILE$" $INFO 2>/dev/null)" ] && echo "$FILE" >> $INFO
    fi
    install -D -m $PERM "$OFILE" "$FILE"
  done
}

install_script() {
  case "$1" in
    -l) shift; local INPATH=$NVBASE/service.d;;
    -p) shift; local INPATH=$NVBASE/post-fs-data.d;;
    *) local INPATH=$NVBASE/service.d;;
  esac
  [ "$(grep "#!/system/bin/sh" $1)" ] || sed -i "1i #!/system/bin/sh" $1
  local i; for i in "MODPATH" "LIBDIR" "MODID" "INFO" "MODDIR"; do
    case $i in
      "MODPATH") sed -i "1a $i=$NVBASE/modules/$MODID" $1;;
      "MODDIR") sed -i "1a $i=\${0%/*}" $1;;
      *) sed -i "1a $i=$(eval echo \$$i)" $1;;
    esac
  done
  case $(basename $1) in
    post-fs-data.sh|service.sh) ;;
    *) cp_ch -n $1 $INPATH/$(basename $1) 0755;;
  esac
}

prop_process() {
  sed -i -e "/^#/d" -e "/^ *$/d" $1
  [ -f $MODPATH/system.prop ] || mktouch $MODPATH/system.prop
  while read LINE; do
    echo "$LINE" >> $MODPATH/system.prop
  done < $1
}

main_install() {
  ui_print "- Installing"

  # Preinstall Addons
  run_addons -h

  # Run user install script
  [ -f "$MODPATH/common/install.sh" ] && . $MODPATH/common/install.sh

  # Install Addons
  run_addons -i

  ui_print "   Installing for $ARCH SDK $API device..."

  # Remove comments from files and place them, add blank line to end if not already present
  for i in $(find $MODPATH -type f -name "*.sh" -o -name "*.prop" -o -name "*.rule"); do
    [ -f $i ] && { sed -i -e "/^#/d" -e "/^ *$/d" $i; [ "$(tail -1 $i)" ] && echo "" >> $i; } || continue
    case $i in
      "$MODPATH/service.sh") install_script -l $i;;
      "$MODPATH/post-fs-data.sh") install_script -p $i;;
      "$MODPATH/sepolicy.rule") [ -e "$PERSISTDIR" ] || continue
                                ui_print "- Installing custom sepolicy patch"
                                cp_ch -n $MODPATH/sepolicy.rule $PERSISTMOD/sepolicy.rule;;
    esac
  done

  # Move files
  $IS64BIT || for i in $(find $MODPATH/system -type d -name "lib64"); do rm -rf $i 2>/dev/null; done  
  [ -d "/system/priv-app" ] || mv -f $MODPATH/system/priv-app $MODPATH/system/app 2>/dev/null
  [ -d "/system/xbin" ] || mv -f $MODPATH/system/xbin $MODPATH/system/bin 2>/dev/null
  if $DYNLIB; then
    for FILE in $(find $MODPATH/system/lib*/* -maxdepth 0 -type d 2>/dev/null | sed -e "s|$MODPATH/system/lib.*/modules||" -e "s|$MODPATH/system/||"); do
      mkdir -p $(dirname $MODPATH/system/vendor/$FILE)
      mv -f $MODPATH/system/$FILE $MODPATH/system/vendor/$FILE
    done
  fi
  cp_ch -n $MODPATH/module.prop $NVBASE/modules/.$MODID-module.prop

  # Handle replace folders
  for TARGET in $REPLACE; do
    ui_print "- Replace target: $TARGET"
    mktouch $MODPATH$TARGET/.replace
  done

  if $BOOTMODE; then
    # Update info for Magisk Manager
    rm -f $NVBASE/modules/$MODID/remove
    mktouch $NVBASE/modules/$MODID/update
    cp -af $MODPATH/module.prop $NVBASE/modules/$MODID/module.prop
  fi
  
  # Remove info and uninstall file if not needed
  [ -s $INFO ] && sed -i "1i FILE=$NVBASE/modules/.$MODID-files\nMODID=$MODID" $MODPATH/uninstall.sh || rm -f $INFO $MODPATH/uninstall.sh

  # Set permissions
  ui_print " "
  ui_print "- Setting Permissions"
  set_perm_recursive $MODPATH 0 0 0755 0644
  set_permissions

  rm -rf $MODPATH/common \
  $MODPATH/system/placeholder $MODPATH/customize.sh \
  $MODPATH/README.md $MODPATH/.git* 2>/dev/null
}

main_uninstall() {
  ui_print " "
  ui_print "- Uninstalling"

  # Uninstall Addons
  run_addons -u

  # Remove files
  if [ -f $NVBASE/modules/.$MODID-files ]; then
    while read LINE; do
      if [ "$(echo -n $LINE | tail -c 1)" == "~" ]; then
        continue
      elif [ -f "$LINE~" ]; then
        mv -f $LINE~ $LINE
      else
        rm -f $LINE
        while true; do
          LINE=$(dirname $LINE)
          [ "$(ls -A $LINE 2>/dev/null)" ] && break 1 || rm -rf $LINE
        done
      fi
    done < $NVBASE/modules/.$MODID-files
  fi
  rm -rf $NVBASE/modules_update/$MODID $NVBASE/modules/.$MODID-module.prop $NVBASE/modules/.$MODID-files 2>/dev/null
  $BOOTMODE && { [ -d $NVBASE/modules/$MODID ] && touch $NVBASE/modules/$MODID/remove; } || rm -rf $MODPATH

  # Run user install script
  [ -f "$MODPATH/common/uninstall.sh" ] && . $MODPATH/common/uninstall.sh
  
  # Postuninstall Addons
  run_addons -v
}

# Check for min/max api version
for i in MINAPI MAXAPI; do
  case $i in 
    "MINAPI") i=$(eval echo \$$i); [ -z $i ] && continue
              [ $API -lt $i ] && abort "! Your system API of $API is less than the minimum api of $i! Aborting!";;
    "MAXAPI") i=$(eval echo \$$i); [ -z $i ] && continue
              [ $API -gt $i ] && abort "! Your system API of $API is greater than the maximum api of $i! Aborting!";;
  esac
done

# Set variables
[ $API -lt 26 ] && DYNLIB=false
[ -z $DYNLIB ] && DYNLIB=false
[ -z $DEBUG ] && DEBUG=false
[ -e "$PERSISTDIR" ] && PERSISTMOD=$PERSISTDIR/magisk/$MODID
INFO=$NVBASE/modules/.$MODID-files
if $DYNLIB; then
  LIBPATCH="\/vendor"
  LIBDIR=/system/vendor
else
  LIBPATCH="\/system"
  LIBDIR=/system
fi
if $BOOTMODE; then
  ORIGDIR="$MAGISKTMP/mirror"
  if $SYSTEM_ROOT && [ ! -L /system/vendor ]; then
    ORIGVEN=$ORIGDIR/system_root/system/vendor
  else
    ORIGVEN=$ORIGDIR/vendor
  fi
else
  mount_apex
fi

#Debug
if $DEBUG; then
  ui_print " "
  ui_print "- Debug mode"
  if $BOOTMODE; then
    ui_print "  Debug log will be written to: /storage/emulated/0/$MODID-debug.log"
    exec 2>/storage/emulated/0/$MODID-debug.log
  else
    ui_print "  Debug log will be written to: /data/media/0/$MODID-debug.log"
    exec 2>/data/media/0/$MODID-debug.log
  fi
  set -x
fi

# Extract files - done this way so we can mount apex before chcon is called from set_perm
ui_print "- Extracting module files"
unzip -o "$ZIPFILE" -x 'META-INF/*' 'common/functions.sh' -d $MODPATH >&2

# Main addons
[ -f "$MODPATH/common/addon.tar.xz" ] && tar -xf $MODPATH/common/addon.tar.xz -C $MODPATH/common 2>/dev/null
run_addons -m

# Load user vars/function
custom

# Determine mod installation status
ui_print " "
if [ -f "$NVBASE/modules/.$MODID-module.prop" ]; then
  if [ $(grep_prop versionCode $NVBASE/modules/.$MODID-module.prop) -ge $(grep_prop versionCode $TMPDIR/module.prop) ]; then
    ui_print "- Current or newer version detected. Uninstalling!"
    main_uninstall
  else
    ui_print "- Older version detected. Upgrading!"
    [ -f "$MODPATH/common/upgrade.sh" ] && . $MODPATH/common/upgrade.sh
    main_uninstall
    mkdir -p $MODPATH
    unzip -o "$ZIPFILE" -x 'META-INF/*' 'common/functions.sh' -d $MODPATH >&2
    main_install
  fi
else
  main_install
fi

# Complete (un)install
cleanup
