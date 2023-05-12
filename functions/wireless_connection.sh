#!/bin/bash
# This file is imported by backup.sh

function wireless_connection() {
  cecho "Warnings:"
  cecho "1. Wireless backups are experimental and might not work on all devices."
  cecho "2. Your computer and phone need to be connected to the same WiFi network."
  cecho "3. Keep your phone connected to the PC until the connection is established."
  cecho "Press Enter to continue."
  wait_for_enter

  device_ip=$(adb shell ip addr show wlan0 | grep 'inet ' | cut -d ' ' -f 6 | cut -d / -f 1)
  # Check if running on Android 11 or higher.
  # Android 11+ devices have to be manually connected wirelessly, so we need to ask the user for the device port.
  # `device_ip` is the device ip address *without the port*, available on all devices.
  # `device_ip_port` is the device ip address AND port, available on android 11+.
  android_version="$(adb shell getprop ro.build.version.release | tr -d '\r' | bc)"
  if (( android_version > 10 )); then
    cecho "Running on Android 11 or higher - automatic wireless connections are not supported."
    cecho "Please open the settings app on your device, and search for 'Wireless debugging'. Enable the option, press 'Pair device with pairing code', and enter the IP address and port of your device below:"
    # TODO: use get_text_input instead of read
    #get_text_input "Device IP & Port:" device_ip_port "$device_ip"
    read -p "Pairing IP address & Port: " device_ip_port
    cecho "Pairing device..."
    adb pair "$device_ip_port"
    cecho "You now have to enter the IP address and port that's shown in the settings app (not the one shown in the pairing screens)."
    read -p "Device IP address & Port: " device_ip_port
    adb connect "$device_ip_port" # this is necessary yet not mentioned in the official documentation
  else # Running on Android 10 or lower
    cecho "Establishing connection..."
    adb tcpip 5353
    sleep 5
    adb connect "$device_ip:5353"
  fi

  cecho "Please unplug your device from the computer, and press Enter to continue."
  wait_for_enter
  adb devices
  cecho "If you can see an IP address in the list above, and it says 'device' next to it, then you have successfully established a connection to the phone."
  cecho "If it says 'unauthorized' or similar, then you need to unlock your device and approve the connection before continuing."
}