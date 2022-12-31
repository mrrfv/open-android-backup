# Please refer to README.md


# This function is ran after the script copies the internal storage, contacts, apps and other data.
# You can use it to get more data from your device.
function backup_hook() {
    mkdir -p ./backup-tmp/Hooks/example-hook/ # create directory structure
    get_file /some_directory/ . ./backup-tmp/Hooks/example-hook/ # get a directory
    get_file /another_directory/ some_file ./backup-tmp/Hooks/example-hook/ # get a file
}

# In the after backup hook, you can get the backup archive path using $backup_archive.
# This is useful for uploading your backups to the cloud, among other things.
function after_backup_hook() {
    echo "Backup path: $backup_archive"
    cp "$backup_archive" /mnt/my_cloud_storage_mount/Backups
}

# This function is ran after restoring the internal storage, apps and contacts to the device.
function restore_hook() {
    # if the directory exists, proceed
    if [ -d "./backup-tmp/Hooks/example-hook/" ]; then
        adb push ./backup-tmp/Hooks/example-hook/ /some-directory/
        adb push ./backup-tmp/Hooks/example-hook/some-file /another-directory/
    else
        cecho "Skipping restore hook - a required directory doesn't exist in the backup."
    fi
}