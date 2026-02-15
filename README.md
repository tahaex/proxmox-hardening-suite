# Proxmox Hardening Suite 🛡️

<div align="center">

![Proxmox](https://img.shields.io/badge/Proxmox_VE-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Security](https://img.shields.io/badge/Security-CIS-blue?style=for-the-badge&logo=adguard&logoColor=white)

**Banking-Grade Security for Your Homelab**

Audit and Harden your Proxmox VE node in minutes.
Based on enterprise standards (CIS Benchmarks) and real-world production setups.

[Report Bug](https://github.com/tahaex/proxmox-hardening-suite/issues) · [Request Feature](https://github.com/tahaex/proxmox-hardening-suite/issues)

</div>

---

## 🚨 Why Secure Proxmox?
A default Proxmox installation is designed for usability, not security.
*   Root SSH is often enabled.
*   Fail2Ban is missing (brute-force attacks are easy).
*   Kernel network stack is unoptimized.
*   Enterprise repositories throw unrelated errors.

**`proxmox-hardening-suite`** fixes this.

## 🛠️ The Scripts

### 1. `audit.sh` (Read-Only)
Checks your system against 5 key security metrics:
*   [ ] SSH Root Login Status
*   [ ] Fail2Ban Installation & Activity
*   [ ] PVE Firewall Status
*   [ ] Repository Configuration (No-Subscription)
*   [ ] Kernel Hardening (BBR, Spoofing protection)

**Usage:**
```bash
bash audit.sh
```

### 2. `harden.sh` (Interactive Fixer)
Applies fixes step-by-step. You choose what to apply.
*   **Repo Fix**: Switches from Enterprise to No-Subscription repos.
*   **Fail2Ban**: Installs and configures jails for Proxmox GUI (8006) and SSH (22).
*   **SSH Hardening**: Disables Root Login and Password Authentication (Keys only).
*   **Kernel Tuning**: Enables BBR congestion control and IP Spoofing protection.

**Usage:**
```bash
chmod +x harden.sh
./harden.sh
```

---

## ⚠️ Critical Warning
**Do NOT disable Password Authentication or Root Login if you haven't added your SSH Key first.**
You will lock yourself out.
Always keep a backup access method (IPMI, Physical Console, or a second user).

---

## 🧪 Testing
We recommend testing `harden.sh` on a **Nested Proxmox VM** first if you are unsure.

---

## License
MIT License.
Built by **[Netics](https://netics.fr)**.
