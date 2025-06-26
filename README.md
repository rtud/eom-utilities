# PHT Utilities

This repository is a collection of automated scripts, cronjobs and various utilities that don't fit to a specific initiative/project and keep the lights on.

## Keep in mind

These scripts are most likely not automatically deployed to Production environments. They will likely be copy/pasted or transfered to the respective running environments. That's why it's important that any tweaks and changes that we end up making either on the development machines or in the Production environment itself, we make it a rule to trickle back down in this repository.

## Synology Sync

The purpose of this script is to forward Day Ahead and Intra Day spreadsheets to Teletrans. Spreadsheets are populated in specific folders via FTP. Every hour we check if new files have arrived and if so, we forward them via FTP to Teletrans.

The script - [sync.sh](synology/sync.sh) - and the configuration file that has been based off our example - [config.example](synology/config.example) - are to be placed on the Synology server, in the `/volume1/Teletrans/` directory. Once added there, we need to ensure that:

1. the `sync.sh` file has the executable flag applied: `chmod +x /volume1/Teletrans/sync.sh`
2. the `config` file is edited to include all necessary tokens and project configurations, using information that is feature in 1Password
3. both files are adjusted to be owned by the admin user: `chown admin:users /volume1/Teletrans/sync.sh /volume1/Teletrans/config`

### Good to know

- at this time, to be able to connect via SSH to the Synology server:
  - you need to plug in via Ethernet cable to the white router in the technical room
  - you'll need an Administrator's help to have a user w/ admin-level credentials created via the Synology web UI
  - the router's ip is `192.168.10.250`
  - the Synology server's SSH port isn't port forwarded to the outside world and we need to keep it like that
- if you're connecting via SSH to the server, keep in mind:
  - the errors from the script will appear in the `/var/log/bash_err.log` file
- to test that the script is running server side
  - `cd` into the `/volume1/Teletrans` directory via SSH
  - type `./sync.sh` to have the script run, that will display the verbose output of the operations
- to ensure the cronjob will also work as expected, visit the Admin UI and trigger a run of the scheduled task manually
