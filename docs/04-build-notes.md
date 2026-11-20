# Build notes: what went wrong and how it was resolved

These are the problems met while building the lab on 2026-11-19, kept because the fixes explain several choices in the scripts. All of this work was assistant-operated (see the [README](../README.md#who-did-what)).

## The Wazuh appliance did not come back after a reboot

**Symptom.** After the first reboot, `wazuh-indexer` was running but `wazuh-manager` and `wazuh-dashboard` stayed inactive. Agents showed as disconnected and the dashboard port did not answer.

**Cause.** The appliance ships with a first-boot script, started by a systemd timer, that brings the services up in order. It waits for the indexer by calling it with the default `admin` password, and it only enables the manager and dashboard and removes itself after every check passes. The lab rotates that password during setup. From then on the check can never succeed, so the script loops forever and the manager and dashboard are never started or enabled. The journal showed it had already been looping, at the dashboard check, since the password was rotated.

**Fix.** The script and its two units were moved aside (not deleted) to `/root/wazuh-starter-retired`, and its last steps were done directly: `systemctl enable wazuh-manager wazuh-dashboard`. To keep the ordered start the script provided, three systemd drop-ins named `10-soc-lab.conf` were added:

| Unit | Drop-in |
| --- | --- |
| `wazuh-indexer` | `TimeoutStartSec=600` |
| `wazuh-manager` | `After=wazuh-indexer.service`, `TimeoutStartSec=300` |
| `wazuh-dashboard` | `After=wazuh-indexer.service wazuh-manager.service` |

The longer timeouts matter on this host. With the packaged limits (45 seconds for the manager, 3 minutes for the indexer) both services timed out once during a busy boot. After the change, a reboot brought all four services up about 110 seconds into the boot.

**Lesson.** Rotating a default credential can break automation that silently depends on it. Check what else uses a password before and after changing it, and test a reboot.

## An agent cannot be renamed in place

The Ubuntu endpoint was first enrolled under an earlier name. Wazuh's documentation describes removing agents and enrolling them, and has no procedure for renaming one. The agent was enrolled again under the new name with `agent-auth -A soc-ubuntu -m 10.77.0.10`, which the manager registered as a new agent with a new ID, and the old registration was then removed with `manage_agents -r <old id>`. Alerts indexed under the old name stay in the index. Evidence in this repository comes from runs made after the rename.

## cloud-init would have undone a hostname change

Ubuntu and Kali were built from cloud images with a small seed ISO that sets the hostname on every boot check. Changing the hostname by hand is not enough while that seed is attached. On each guest: `preserve_hostname: true` in `/etc/cloud/cloud.cfg.d/`, an empty `/etc/cloud/cloud-init.disabled`, and the seed ISO detached. Disabling cloud-init before detaching the seed matters, because a cloud image that boots without its seed can treat itself as a new instance and regenerate its SSH host keys.

## Paths with spaces and `ssh`

The credential store path contains spaces. Passing `-o UserKnownHostsFile="<path with spaces>"` from Windows PowerShell splits the path at the first space, and `ssh` quietly writes its known-hosts entries to a stray file instead. `ProxyJump` has the same problem when it re-invokes `ssh` with the `-F` path. The helpers now generate an SSH configuration file with quoted paths ([`scripts/host/Lab-SshConfig.ps1`](../scripts/host/Lab-SshConfig.ps1)) and use an explicit, quoted `ProxyCommand` for the hop to Kali.

A related trap: Windows PowerShell 5.1 can put a UTF-8 byte-order mark in front of text piped to a program. The helpers set a BOM-free input encoding for the duration of the call.

## Unattended Windows Server 2025 setup on BIOS firmware

`VBoxManage unattended install` builds an answer file from a stock template. For BIOS firmware that template creates one unformatted partition and tells Setup to install to it. Windows Server 2025 Setup rejects it ("There is an error selecting this partition for install") and stops at the disk page.

The fix was a copy of the template with the standard two-partition MBR layout from Microsoft's documentation: a 500 MB active NTFS system partition and an NTFS Windows partition, with Setup installing to partition 2. It is passed with `--script-template`. The template itself is not in this repository because it derives from a GPL-licensed VirtualBox file; the change is the two `<CreatePartition>` entries, two matching `<ModifyPartition>` entries (`Format` NTFS, `Active` true on the first), and `<PartitionID>2</PartitionID>` under `<InstallTo>`.

Two smaller things followed from the failed first attempt. The unattended installer sets the boot order to disk first, and the first attempt had left a partition table on the disk, so the VM tried to boot the empty disk and stopped. Setting the DVD first for the installation run fixed it. And `VBoxManage unattended install` prints the passwords it was given, so the lab installs with a throwaway password and replaces it inside the guest as the first step after Setup ([`scripts/windows-guest/10-first-boot.ps1`](../scripts/windows-guest/10-first-boot.ps1)).

## Guest control needs one restart, and a console user for ACPI shutdown

After the unattended install, Guest Additions reported a desktop session but `VBoxManage guestcontrol` kept answering "The guest execution service is not ready (yet)". The Guest Additions service only started after one restart of the guest.

Windows Server ignores the ACPI power button when nobody is signed in at the console. With no console user, shut the guest down from inside (`shutdown /s` through guest control) or with `VBoxManage controlvm <vm> shutdown`.

## Restarting and snapshotting the domain controller

Two things went wrong here, and both cost time.

- The first restart after the forest promotion never completed. The guest stopped its services, then sat with both virtual CPUs busy and no disk activity for twenty minutes. A VM reset cleared it and the server came up as a healthy domain controller.
- A **live** snapshot of the running domain controller did not finish in 48 minutes. On a slow disk the running guest changes memory faster than it can be saved. Pausing the VM to let it finish made the snapshot fail, and left VirtualBox with two views of the VM: the API said "running" while the VM was suspended internally. Neither resume, pause nor power-off worked in that state, so the VM process had to be ended. Active Directory recovered on the next boot and was verified again.

The lesson is simple: on this hardware, snapshot the Windows server while it is powered off. The later snapshots were taken that way and took seconds.

## Pausing a VM leaves its clock behind

The Wazuh appliance was paused for eight minutes during the snapshot trouble. When it resumed, its clock was 409 seconds slow, which would have put wrong timestamps on every alert. `chronyc makestep` stepped it back. Check the manager's clock before any run whose timestamps you intend to keep.

The Windows guest's clock also wandered by a few seconds over a few minutes relative to the host, so the write-ups state times to the second and say so.

## A packaged desktop app does not see the real `%LOCALAPPDATA%`

The assistant that did this work ran inside a packaged (MSIX) Windows desktop app. Windows redirects such an app's writes under `%LOCALAPPDATA%` to a private per-app folder. The credential store was "moved" to its new name and everything appeared to work, but the files only existed in that private folder: VirtualBox's background service could not see temporary files written there, and an ordinary PowerShell window would not have found the store at all.

The store was copied to the real location with a process started outside the app, and owner-only permissions were restored on the SSH key, which OpenSSH refuses to use otherwise. The helpers now put their short-lived files in `%TEMP%`, which is not redirected.

**Lesson.** When automation and a person are meant to share a path, test it from both sides.

## Slow virtual machines

Two host facts explain most of the waiting. VirtualBox runs here on the Windows Hypervisor Platform backend (the VM logs say "VT-x is not available"), which is slower than native virtualization. And the lab's virtual disks sit on an external USB hard drive, where the Windows installation wrote at about 5 MB/s. One Linux guest also stalled once in early boot while the host was copying a large file to the same drive; a VM reset cleared it. Moving the lab to an internal SSD is the obvious improvement.
