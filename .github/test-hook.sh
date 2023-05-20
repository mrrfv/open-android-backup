# Please refer to README.md


# This function is ran after the script copies the internal storage, contacts, apps and other data.
# You can use it to get more data from your device.
function backup_hook() {
    echo "[BACKUP HOOK TEST]"
    mkdir -pv ./backup-tmp/Hooks/example-hook/
}

# In the after backup hook, you can get the backup archive path using $backup_archive.
# This is useful for uploading your backups to the cloud, among other things.
function after_backup_hook() {
    echo "[AFTER BACKUP HOOK TEST] Backup path: $backup_archive"
}

# This function is ran after restoring the internal storage, apps and contacts to the device.
function restore_hook() {
    echo "[RESTORE HOOK TEST]"
}