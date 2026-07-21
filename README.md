# Snarch

Snarch is a Bash-based utility that provides transactional system updates for Arch Linux systems using LVM snapshots.

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
- [ ] Multi-distribution support
- [ ] Integration tests
- [ ] Configuration file

---

## Requirements

- Bash
- LVM2
- bc
- GNU coreutils
- sed
- awk

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

Before creating a snapshot, Snarch estimates whether the Volume Group contains enough free space.

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
[1] Automatic update
[2] Show volumes
[3] Create snapshot
[4] Verify snapshot viability
[0] Exit
```

---

## Design Goals

- Simplicity
- Low overhead
- Native Linux tools only
- Minimal external dependencies
- Fully scriptable

---

## Future Roadmap

- DNF support
- APT support
- Zypper support
- Logging improvements
- Automatic rollback on boot failure


---

## Limitations

- Requires LVM.
- Only protects data stored inside the snapshot-covered Logical Volume.
- Snapshot capacity depends on the amount of changed blocks.
- Extremely large updates may exhaust the snapshot space.

