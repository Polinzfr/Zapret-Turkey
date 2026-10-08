🌍 **Language:** [English](README.md) | [Türkçe](README.tr.md)

# Zapret Turkey

A fully BAT/CMD-based, open-source **Windows tool against DPI-based access blocking in Turkey**. It uses the [Zapret](https://github.com/bol-van/zapret) engine (`winws.exe`) to work around ISP-level DPI interference with connections to apps and sites such as Discord, Roblox and Steam — all from a single color-coded CMD menu. No installer, no Python, no .NET.

![Application Screenshot](docs/screenshot(en).png)

---

## Features

- **Single-file CMD menu** — ANSI-colored, nothing to install; English and Turkish interface, switchable at any time in Settings (no restart)
- **Three ready-made profiles** — Stable / Compatibility / Strong, kept as plain-text `.conf` files under `profiles/` (not hardcoded)
- **Auto Test** — tries the three profiles in turn, runs basic connectivity checks against Discord, Roblox and Steam, and recommends one; runs completely hidden, no windows opening or closing
- **Target / exclude site lists** — the bypass is applied only to the sites in `profiles/target-hosts.txt`, everything else passes through untouched; add or remove sites from the menu and test a single site on the spot
- **Profile export / import** — save the selected profile to a config file and load it back through the normal Windows Save / Open dialogs
- **GitHub Issue report** — generates a block in the [`docs/ISS.md`](docs/ISS.md) format (profile, IPv4/IPv6, DNS, Discord/Roblox/Steam results) and copies it to the clipboard
- **Windows service** — install, uninstall, start and stop; starts on boot without opening any window
- **Start at logon** — a service-free alternative: a hidden scheduled task starts the engine about 15 seconds after you log in
- **Watchdog** — restarts `winws.exe` if it crashes; pressing Stop is respected, and it gives up after 3 failed restarts in a row
- **VPN auto-pause** — stops the engine while a VPN (ProtonVPN, Windscribe and other VPN adapters) is connected and starts it again after the VPN has been gone for about 20 seconds; the official WireGuard app is ignored; works with the Windows service as well
- **DNS Assistant** — detects your active network adapter and sets Cloudflare or Google DNS (IPv4, and IPv6 only if the adapter has a real IPv6 address), then verifies the result; always reversible (reset to DHCP)
- **Diagnostics** — checks administrator rights, required files, other WinDivert-based software, IPv4/IPv6, connectivity (Discord, Roblox, Steam, general HTTPS) and **DNS** (your system's answers compared with `1.1.1.1`, with a warning if the modem's DNS returns fake addresses); optionally writes a shareable report with no personal data
- **Debug Mode** — resolved paths, parsed profile arguments, admin/service/running state, and the full command line and stderr of the last start attempt on one screen
- **Detailed logs** — `logs/app.log` and `logs/engine_stderr.log`
- **Leaves DNS and UDP/QUIC alone by default** — DNS is only changed if you choose to run the DNS Assistant

---

## What This Project Does NOT Do

- **It is not a VPN** — it does not encrypt your traffic or route it through another server; it only changes how the TCP/443 handshake is packetized
- **It does not change your DNS by default**
- **It does not touch UDP/QUIC traffic**
- **It does not track you, collect data or send anything out** — no IP-info lookups, and the diagnostic report contains no real IP, MAC address, computer name, username or file paths

---

## System Requirements

| Requirement | Details |
|-------------|---------|
| Operating System | Windows 10 / Windows 11 (x64) |
| Privileges | Administrator — the app asks for it and restarts itself elevated if needed |
| curl.exe | Built into Windows 10 1803+ and Windows 11 — used by Auto Test and Diagnostics |
| PowerShell | Built into Windows — used only by optional features (VPN detection, file dialogs, the DNS check in Diagnostics); start/stop, profiles and the service do not need it |
| Python / .NET | Not required |

---

## Installation

1. Download the latest ZIP from the [Releases](https://github.com/Polinzfr/Zapret-Turkey/releases) page (or clone the repository):

```bash
git clone https://github.com/Polinzfr/Zapret-Turkey.git
```

2. Extract the folder wherever you like — **do not move it afterwards**. The Windows service and the scheduled tasks (start at logon, Watchdog, VPN auto-pause) remember the folder path; if you move it, turn those features off and on again and reinstall the service.
3. Double-click `ZapretTurkey.bat` and approve the administrator prompt.

---

## Usage

![Application Menu](docs/Screenshot(en).png)

1. Run `ZapretTurkey.bat`
2. Pick **[4] Auto Test** and save the recommended profile (or choose one yourself in **[3] Profile**)
3. Press **[1] Start**
4. Fully close and reopen Discord, Roblox or whatever app you are testing
5. Optional: use **[5] Service Settings** to run it as a service, start it at logon, or turn on Watchdog / VPN auto-pause
6. If something does not work, run **[6] Diagnostics**

| Menu | What it does |
|---|---|
| **[1] Start / [2] Stop** | Starts or stops `winws.exe` with the selected profile. On failure the real reason is shown on screen (missing file, broken profile, not administrator, engine exited immediately plus its stderr) — the window never closes silently. |
| **[3] Profile** | Change the profile, export it to a file, import it from a file, or generate a GitHub Issue report. |
| **[4] Auto Test** | Tries Stable / Compatibility / Strong in turn, hidden, and summarizes as `STABLE = PASS/FAIL`. |
| **[5] Service Settings** | [1]-[4] install / uninstall / start / stop the Windows service, [5]/[6] start at logon on/off, [7]/[8] Watchdog on/off, [9]/[10] VPN auto-pause on/off. Start at logon and Watchdog are not available while the Windows service is installed, because the service already starts the engine at boot. |
| **[6] Diagnostics** | System, WinDivert conflict, IPv4/IPv6, connectivity and DNS checks; optionally writes `logs/diagnostic-report.txt`. |
| **[7] Settings** | [1] leave DNS alone, [2] DNS Assistant (Cloudflare or Google), [3] reset DNS to automatic (DHCP), [4] debug tag, [5] language. |
| **[8] Logs** | Shows recent logs and errors, opens the logs folder, shows the last engine stderr. |
| **[9] Tools** | [1] edit the site lists, [2] test a specific site, [3] Debug Mode, [4] VPN detection test. |

---

## Profiles

| Profile | Method | Notes |
|---|---|---|
| **Stable** | `--dpi-desync=hostfakesplit` | Light split right after the SNI/host position — one of the least invasive profiles |
| **Compatibility** | `--dpi-desync=fake` | A fake-packet profile that touches the real stream less |
| **Strong** | `--dpi-desync=multisplit` | Stronger split at the method and host positions |

All three work only on **TCP/443**, and only for the sites listed in `profiles/target-hosts.txt` (sites in `profiles/exclude-hosts.txt` are never touched). **UDP/QUIC is not filtered**, because in earlier testing aggressive UDP interference broke Discord and Roblox — see [`docs/ANALYSIS.md`](docs/ANALYSIS.md). To add a profile you only edit the `profiles/` folder, not the `.bat` file. If you installed the Windows service, reinstall it after changing the profile so the new parameters take effect.

```ini
# profiles/stable.conf
NAME=Turkiye Stable (HostFakeSplit)
PORT_TCP=443
ARGS=--dpi-desync=hostfakesplit --dpi-desync-split-pos=sld --dpi-desync-repeats=1 --dpi-desync-autottl=1:4-10 --dpi-desync-skip-nosni=0 --dpi-desync-start=n2 --dpi-desync-cutoff=n5
```

---

## DNS and IPv6 Notes

- Some ISP modems and routers answer DNS queries for blocked domains (for example `discord.com`) with a fake address. Then connections fail with certificate errors no matter which profile is running. **Diagnostics** compares your system's answers with `1.1.1.1` and tells you when this happens; **Settings → DNS Assistant** switches to Cloudflare or Google DNS, and **Settings → [3]** puts it back to automatic.
- If your ISP or modem does not provide IPv6, an IPv6 DNS server at the top of the adapter's DNS list (the modem's `fe80::` address or one set by hand) cannot be reached. Windows falls back to the next server, so apps keep working, but tools that only query the first server, such as `nslookup`, time out. This is not a Zapret Turkey error. The DNS Assistant only offers IPv6 DNS if the adapter has a real IPv6 address.

---

## Project Structure

```
Zapret-Turkey/
├── ZapretTurkey.bat        # Main menu / application
├── engine/                 # Zapret engine (winws.exe, WinDivert.dll, WinDivert64.sys, ...)
├── profiles/               # Plain-text profiles and site lists
│   ├── stable.conf
│   ├── compatibility.conf
│   ├── strong.conf
│   ├── target-hosts.txt    # Sites the bypass is applied to
│   └── exclude-hosts.txt   # Sites that are never touched
├── lang/                   # Interface language files
│   ├── en.lang
│   └── tr.lang
├── scripts/
│   ├── lang-load.bat
│   ├── install-service.bat
│   ├── uninstall-service.bat
│   └── diagnostics.bat
├── config/                 # settings.conf and small state files (created while running)
├── logs/                   # app.log, engine_stderr.log, diagnostic report (created while running)
├── licenses/
│   └── LICENSE-windivert.txt
├── docs/
│   ├── ANALYSIS.md         # GoodbyeDPI vs Zapret technical comparison
│   ├── ISS.md              # Community-filled ISP-profile template
│   ├── TROUBLESHOOTING.md
│   └── CONTRIBUTING.md
├── CHANGELOG.md
├── LICENSE
├── README.md               # English documentation
└── README.tr.md            # Turkish documentation
```

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Engine | [Zapret](https://github.com/bol-van/zapret) (`winws.exe`) |
| Packet driver | [WinDivert](https://github.com/basil00/Divert) (LGPLv3, license text in `licenses/`) |
| Interface | BAT/CMD with ANSI colors |
| Connectivity tests | `curl.exe` (built into Windows) |
| Background tasks | Windows Task Scheduler (`schtasks`) with hidden VBScript launchers |
| Optional features | Windows PowerShell (VPN detection, file dialogs, DNS check) |

---

## Known Limitations

- **There is no single, guaranteed profile for every ISP.** FTTH/VDSL/ADSL/GPON, different modems and routers, and IPv4/IPv6/CGNAT can all change how DPI behaves. [`docs/ISS.md`](docs/ISS.md) is a community-filled template and deliberately contains no invented ISP mapping. Testing which profile works on your ISP and sharing it through an Issue or PR is the most valuable contribution.
- Auto Test only checks basic TCP/TLS connectivity; it does not verify in-app behavior (messaging, CDN, WebSocket) — open the apps yourself to test that.
- VPN detection is based on network adapter names and descriptions plus Windows VPN connections. If your VPN is not detected, run **Tools → [4] VPN Detection Test** and open an Issue with the output.
- The IPv6 line in Diagnostics also counts link-local addresses (`fe80::`), so it can say "Found" even if your ISP provides no IPv6.
- It has been tested on a single user, machine and ISP so far. Please open an Issue for problems on a different Windows version, ISP or network setup — **[3] Profile → GitHub Issue report** and the Diagnostics report make that quick.
- **Do not run it together with GoodbyeDPI** — both use the WinDivert driver and can conflict (Diagnostics checks for this). See [`docs/ANALYSIS.md`](docs/ANALYSIS.md) for the comparison.

See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) for common problems and fixes.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit your changes
4. Open a Pull Request

See [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) for the full guide.

---

## License

The BAT/CMD scripts and documentation in this repository are licensed under the [MIT License](LICENSE). The binaries under `engine/` are subject to the license terms of their upstream projects (Zapret, WinDivert).

---

## Disclaimer

This tool only changes how your own connections are packetized; it does not guarantee access to any site or service, and it is not a VPN. Use it responsibly and respect the laws that apply to you and the terms of service of the platforms you use.
