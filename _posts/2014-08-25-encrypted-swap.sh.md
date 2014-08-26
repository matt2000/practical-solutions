---
layout: post
title: How to Enable an Encrypted Swap Partition
tags: Ubuntu 14.04
---

I came up with this solution when `ecryptfs-setup-swap` failed to work
on my system, possibly because I have a GUID Partition Table on my disk.
So I used the Ubuntu Disks GUI utility to format my swap partition as 
LUKS+ext4 and then put together this script to enable it on log-in.

/etc/profile.d/encrypted-swap.sh
--------------------------------
    
### System specific parameters
    
    PARTITION_RAW="/dev/sda10"
    PARTITION_UNLOCKED="/dev/mapper/luks-5edddf9e-76b9-4030-9fd3-90502211ace3"
    
### The code
First, make sure the swap partition isn't already unlocked.
    
    if [[ -z `ls $PARTITION_UNLOCKED` ]];
    then
      echo "Unlocking encrypted swap partition..."  
      udisksctl unlock -b $PARTITION_RAW
    fi
    
Make sure it's not already enabled as a swap device.
    
    if [[ -z `swapon -s | grep $PARTITION_UNLOCKED` ]]
    then
      echo "Enabling swap..."
      sudo swapon $PARTITION_UNLOCKED
    fi
    
To ensure this works for GUI sessions run this script as a 
"Start-up Application" using the GUI tool for such, or by manually adding a 
.desktop file to ~/.config/autostart to run this script, e.g., 

    gnome-terminal -e "/etc/profile.d/encrypted-swap.sh"
