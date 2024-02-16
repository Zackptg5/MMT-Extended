### v3.6 - 2.16.2024
* Update magisk delta support (now called kitsune)
* Add support for APatch
* Add support for magisk atomic mounting (in theory)

### v3.5 - 9.11.2023
* Define SERVICED, POSTFSDATAD, and SYSTEM_ROOT if not already defined - were removed or renamed in magisk 26.2 and 26.3 for no good reason :/

### v3.4 - 9.3.2023
* Bug fix for boot-completed scripts

### v3.3 - 8.13.2023
* Updates for KSU
  * min ksu version now v0.6.6
  * added support for boot-completed scripts

### v3.2 - 8.11.2023
* Bug fixes for custom partitions

### v3.1 - 7.25.2023
* Add override for extra partitions in event you have workaround for support for regular magisk installs

### v3.0 - 7.10.2023
* Add support for KSU modules
* Add support for magisk delta
* Add support for other partitions - note that you need magisk delta or ksu installed to use these
* Make debug default behavior, remove flag
* Fix uninstall script so it'll clean up files outside of module folder if user manually deletes module folder

### v2.1 - 5.24.2023
* Update variables for magisk 26

### v2.0 - 1.29.2022
* Update for magisk 24
  * Added zygisk module support
* Misc fixes

### v1.8 - 11.21.2021
* Fix for magisk canary
* Minimum magisk version now 20.4

### v1.7 - 9.9.2021
* Small fix for magisk canary

### v1.6 - 9.12.2020
* Updates for latest magisk - minmagisk is 20 now
* Added back ro.build.product to device_check for older roms
* Moved credits so it'll work with latest magisk mod template

### v1.5 - 3.27.2020
* Have debug log be part of regular log, remove superfluous stuff, module dev can just add what they want
* Removed addon runtime confusion - all scripts are install.sh now
* Added manufacturer option to device_check
* Fixes for Magisk 20.4

### v1.4 - 2.20.2020
* Add more vendor perms
* Fixed uninstall.sh script install behavior - it'll install if there's files outside of modpath or if there's custom logic at the top of it
* Misc bug fixes

### v1.3 - 1.22.2020
* Move debug log to same location as magisk log - Download folder
* Add proper chcon for vendor files - fixes various issues with audioflinger and maybe more with android Q
* Remove empty folders after moving files for DYNLIB
* Fix api check bug

### v1.2 - 1.17.2020
* Fixed bug in debug log
* Fixed DYNLIB so it won't move empty files (replacements) to vendor
* Magisk manager only installs now - will automatically remove module if flashed in recovery
* Removed extra crap that was needed for recovery installs
* Removed common/uninstall and upgrade scripts, no need for them anymore
* Removed mount_part function - no need for it now since recovery is no longer supported - just remount partition as rw
* More in line with regular magisk module template now - flashing zip always installs/upgrades mod. To uninstall, use magisk manager

### v1.1 - 1.11.2020
* No longer use .core - it'll be deprecated soon
* Fix for uninstall
* Fix bug in debug function during uninstalls
* Misc fixes

### v1.0 - 1.4.2020
* Initial release