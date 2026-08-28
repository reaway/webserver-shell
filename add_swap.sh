#!/bin/bash

Print_Sys_Info() {
  cat /etc/issue
  cat /etc/*-release
  uname -a
  MemTotal=$(awk '/MemTotal/ {printf( "%d\n", $2 / 1024 )}' /proc/meminfo)
  echo "Memory is: ${MemTotal} MB "
  df -h
}

Add_Swap() {
  free -h
  swapon --show

  Disk_Avail=$(($(df -mP /var | tail -1 | awk '{print $4}' | sed s/[[:space:]]//g) / 1024))

  Enable_Swap='y'
  DD_Count='1024'
  if [[ "${MemTotal}" -lt 1024 ]]; then
    DD_Count='1024'
    if [[ "${Disk_Avail}" -lt 5 ]]; then
      Enable_Swap='n'
    fi
  elif [[ "${MemTotal}" -ge 1024 && "${MemTotal}" -le 2048 ]]; then
    DD_Count='2048'
    if [[ "${Disk_Avail}" -lt 13 ]]; then
      Enable_Swap='n'
    fi
  elif [[ "${MemTotal}" -ge 2048 && "${MemTotal}" -le 4096 ]]; then
    DD_Count='4096'
    if [[ "${Disk_Avail}" -lt 17 ]]; then
      Enable_Swap='n'
    fi
  elif [[ "${MemTotal}" -ge 4096 && "${MemTotal}" -le 16384 ]]; then
    DD_Count='8192'
    if [[ "${Disk_Avail}" -lt 19 ]]; then
      Enable_Swap='n'
    fi
  elif [[ "${MemTotal}" -ge 16384 ]]; then
    DD_Count='8192'
    if [[ "${Disk_Avail}" -lt 27 ]]; then
      Enable_Swap='n'
    fi
  fi

  Swap_Total=$(awk '/SwapTotal/ {printf( "%d\n", $2 / 1024 )}' /proc/meminfo)
  if [[ "${Enable_Swap}" = "y" && "${Swap_Total}" -le 512 && ! -s /var/swapfile ]]; then
    echo "Add Swap file..."
    [ $(cat /proc/sys/vm/swappiness) -eq 0 ] && sysctl vm.swappiness=10
    dd if=/dev/zero of=/var/swapfile bs=1M count=${DD_Count}
    chmod 0600 /var/swapfile
    echo "Enable Swap..."
    /sbin/mkswap /var/swapfile
    /sbin/swapon /var/swapfile
    if [ $? -eq 0 ]; then
      [ $(grep -L '/var/swapfile' '/etc/fstab') ] && echo "/var/swapfile swap swap defaults 0 0" >>/etc/fstab
      /sbin/swapon -s
    else
      rm -f /var/swapfile
      echo "Add Swap Failed!"
    fi
  fi

  free -h
  swapon --show
}

Print_Sys_Info
Add_Swap
