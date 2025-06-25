# PHT Utilities

This repository is a collection of automated scripts, cronjobs and various utilities that keep the

## Synology Sync

The purpose of this script is to forward Day Ahead and Intra Day spreadsheets to Teletrans. Spreadsheets are populated in specific folders via FTP. Every hour we check if new files have arrived and if so, we forward them via FTP to Teletrans.

The script - [sync.sh](synology/sync.sh) - and the configuration file that has been based off our example - [config.example](synology/config.example) - are to be placed on the Synology server, in the `/volume1/Teletrans/` directory. Once added there, we need to ensure that:

1. the `sync.sh` file has the executable flag applied: `chmod +x /volume1/Teletrans/sync.sh`
2. the `config` file is edited to include all necessary tokens and project configurations, using information that is feature in 1Password
3. both files are adjusted to be owned by the admin user: `chown admin:users /volume1/Teletrans/sync.sh /volume1/Teletrans/config`

### Good to know

- if you're connecting via SSH to the server, keep in mind:
  - the errors from the script will appear in the `/var/log/bash_err.log` file
- to test that the script is running server side
  - `cd` into the `/volume1/Teletrans` directory via SSH
  - type `./sync.sh` to have the script run, that will display the verbose output of the operations
- to ensure the cronjob will also work as expected, visit the Admin UI and trigger a run of the scheduled task manually
