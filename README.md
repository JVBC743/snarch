# SnArch

SnArch is a Bash-based utility that provides transactional system updates for Arch Linux systems using LVM snapshots.

The project automatically creates a snapshot before updating the operating system, validates the integrity of the updated environment and, if necessary, restores the previous system state through an LVM rollback.

The objective is to reduce the risks involved in package upgrades by providing a lightweight recovery mechanism inspired by transactional operating systems.

---

## Features

- Automatic LVM snapshot creation
- Snapshot viability analysis
- Automatic system update
- Post-update validation
- Rollback through LVM snapshot merge
- Volume and storage inspection
- Interactive terminal interface (TUI)
- Debug mode for troubleshooting

---

## Current Status

This project is currently under active development.

Implemented features include:

- [x] LVM information gathering
- [x] Snapshot creation
- [x] Snapshot deletion
- [x] Rollback execution
- [x] Snapshot viability calculation
- [x] Interactive CLI
- [ ] Automatic rollback after failed validation
- [ ] Integration tests
- [ ] Configuration file

---

## Requirements

- Arch Linux operating system
- English language setting in "locale.conf"
- Bash
- LVM2
- bc
- GNU coreutils
- sed
- awk
- pacman-contrib (specifically the pactree command)
- Internet connection
- SystemD environment
- "less" command

The root filesystem must reside on an LVM Logical Volume.

---

## Project Structure

```
controller.sh     Entry point
lvm.sh            Snapshot and LVM management
update.sh         System update logic
view.sh           Terminal interface
log.sh            Logging utilities
debug.sh          Debug functions
```

---

## Workflow

```
               Start
                 │
                 ▼
     Verify snapshot viability
                 │
                 ▼
       Create LVM snapshot
                 │
                 ▼
         Update the system
                 │
                 ▼
      Execute validation routines
                 │
       ┌─────────┴─────────┐
       │                   │
       ▼                   ▼
   Validation OK      Validation Failed
       │                   │
       ▼                   ▼
 Remove snapshot      Merge snapshot
       │                   │
       └─────────┬─────────┘
                 ▼
                End
```

---

## Snapshot Viability

Before creating a snapshot, SnArch estimates whether the Volume Group contains enough free space.

The calculation currently considers:

- Total size of all Logical Volumes
- Total Volume Group capacity
- Available free space
- Minimum recommended free space

If the available capacity is considered insufficient, the snapshot operation is aborted.

---

## Rollback

Rollback is performed using the native LVM merge mechanism:

```bash
lvconvert --merge /dev/<vg>/<snapshot>
```

The merge is completed during the next system boot.

---

## Usage

Run as root:

```bash
sudo ./controller.sh
```

Available operations:

```
[1]: Just automate already! (to trigger the main process)
[2]: Show me the volumes. (for volume display)
[3]: Take a snapshot. (to create a snapshot)
[4]: Verify snapshot viability (to see if it is possible to create a snapshot)
[0]: Exit the script
```

---

## Design Goals

- Simplicity
- Low overhead
- Minimal external dependencies
- Fully scriptable

---

## Future Roadmap

- Logging improvements
- Debugging improvements

---

## Limitations

- Requires LVM.
- Snapshot capacity depends on the amount of changed blocks.
- Extremely large updates may exhaust the snapshot space.
