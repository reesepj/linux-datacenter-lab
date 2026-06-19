# Lab 05 — systemd and Services

> **Module format.** Every lab uses the same shape: Objectives, Background, Lab, Verification, Why it matters, Cleanup. Type the commands; do not paste blindly. Read each line before you run it.

## Objectives

By the end of this module you will:

- Control services with `systemctl`: status, start, stop, restart, enable, disable.
- Read service and boot logs with `journalctl` and filter them quickly.
- Inspect a unit file and understand what it declares.
- Write, install, and enable your own custom systemd unit.
- Break a real service (nginx), diagnose it from the logs, and fix it.
- Understand targets and how systemd brings a machine to a usable state at boot.

## Background

`systemd` is the init system and service manager on Debian and most modern Linux. It is PID 1: the first process the kernel starts, and the parent of everything else. It starts services in dependency order, restarts them when they die, captures their logs into the **journal**, and tracks the overall boot state through **targets** (the rough equivalent of old runlevels).

You interact with it through two tools:

- `systemctl` — control and query **units** (services, sockets, timers, mounts, targets).
- `journalctl` — read the logs systemd collected.

A **unit** is described by a small declarative file (e.g. `/lib/systemd/system/nginx.service`). Your custom units live in `/etc/systemd/system/`, which overrides the vendor copies. This lab uses `nginx`, which is preinstalled.

## Lab

### 1. Inspect a real service

```bash
systemctl status nginx
```

Expected (abridged):

```
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since ...; 2min ago
```

The two words that matter most: **Loaded** (is it set to start at boot — `enabled`/`disabled`) and **Active** (is it running right now — `active`/`inactive`/`failed`).

### 2. Start, stop, restart

```bash
sudo systemctl stop nginx
systemctl is-active nginx          # inactive
curl -sI http://localhost | head -1   # connection refused — nothing listening

sudo systemctl start nginx
systemctl is-active nginx          # active
curl -sI http://localhost | head -1   # HTTP/1.1 200 OK

sudo systemctl restart nginx       # full stop+start
sudo systemctl reload nginx        # reload config without dropping connections
```

### 3. Enable vs. start (boot persistence)

`start` affects **now**; `enable` affects **next boot**. They are independent.

```bash
systemctl is-enabled nginx         # enabled
sudo systemctl disable nginx       # will NOT start at next boot (still running now)
systemctl is-enabled nginx         # disabled
sudo systemctl enable nginx        # restore boot start
sudo systemctl enable --now nginx  # enable AND start in one shot
```

### 4. Read logs with journalctl

```bash
journalctl -u nginx                # all log lines for this unit
journalctl -u nginx -n 20          # last 20 lines
journalctl -u nginx --since "10 min ago"
journalctl -u nginx -f             # follow live (Ctrl-C to quit)
journalctl -xe                     # last events with explanations — your go-to after a failure
journalctl -b                      # everything since this boot
journalctl -p err -b               # only error-priority and worse since boot
```

In a second terminal run `journalctl -u nginx -f`, then `sudo systemctl restart nginx` in the first and watch the stop/start lines appear.

### 5. Inspect the unit file

```bash
systemctl cat nginx                # show the effective unit file
systemctl show nginx -p ExecStart -p Restart -p WantedBy
```

`systemctl cat` prints the real file with its path header. Note the `[Unit]`, `[Service]`, and `[Install]` sections — you are about to write your own.

### 6. Write a custom oneshot unit

A common ops task: run a small command at boot and record that it ran. Create the script:

```bash
sudo tee /usr/local/bin/lab-heartbeat.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
echo "lab heartbeat at $(date -Is) on $(hostname)"
EOF
sudo chmod +x /usr/local/bin/lab-heartbeat.sh
```

Now the unit. Use `Type=oneshot` for a task that runs to completion rather than staying resident:

```bash
sudo tee /etc/systemd/system/lab-heartbeat.service >/dev/null <<'EOF'
[Unit]
Description=Lab heartbeat — logs a line at boot
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lab-heartbeat.sh

[Install]
WantedBy=multi-user.target
EOF
```

Tell systemd to re-read unit files, then run and enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl start lab-heartbeat.service
journalctl -u lab-heartbeat.service
```

Expected:

```
lab heartbeat at 2026-06-19T14:02:11+00:00 on linux-lab
```

```bash
sudo systemctl enable lab-heartbeat.service   # runs at every boot
systemctl is-enabled lab-heartbeat.service    # enabled
```

### 7. Break nginx on purpose, then fix it from the logs

> **Snapshot first** (from the KVM host): `sudo virsh snapshot-create-as linux-lab pre-lab05 "before breaking nginx"`. Roll back with `sudo virsh snapshot-revert linux-lab pre-lab05` if you get stuck.

Sabotage the config with an invalid directive:

```bash
echo "this_is_not_valid_nginx;" | sudo tee -a /etc/nginx/nginx.conf
sudo systemctl restart nginx
```

The restart fails:

```
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
```

Diagnose — let the logs tell you exactly what is wrong:

```bash
systemctl status nginx             # Active: failed
journalctl -xeu nginx | tail -20
```

Expected clue:

```
nginx: [emerg] unknown directive "this_is_not_valid_nginx" in /etc/nginx/nginx.conf:NN
```

nginx ships a config validator — always use it before restarting:

```bash
sudo nginx -t
```

```
nginx: [emerg] unknown directive "this_is_not_valid_nginx" in /etc/nginx/nginx.conf:NN
nginx: configuration file /etc/nginx/nginx.conf test failed
```

Fix it by removing the bad line, re-test, and restart:

```bash
sudo sed -i '/this_is_not_valid_nginx;/d' /etc/nginx/nginx.conf
sudo nginx -t                      # syntax is ok ... test is successful
sudo systemctl restart nginx
systemctl is-active nginx          # active
curl -sI http://localhost | head -1   # HTTP/1.1 200 OK
```

The loop you just ran — **read the error → reproduce with the tool's own validator → fix → re-validate → restart → confirm** — is the core service break-fix workflow.

### 8. Targets and boot (brief)

Targets group units into states the machine can be brought to:

```bash
systemctl get-default              # graphical.target or multi-user.target
systemctl list-units --type=target # active targets
systemctl list-dependencies multi-user.target | head -20
systemd-analyze blame | head -10   # what took longest to start at boot
```

`multi-user.target` is a fully booted, networked, non-graphical system — the normal state for a server. Your custom unit's `WantedBy=multi-user.target` is exactly why enabling it makes it start at boot.

## Verification

- `systemctl is-active nginx` prints `active` and `curl -sI http://localhost` returns `HTTP/1.1 200 OK`.
- `systemctl is-enabled lab-heartbeat.service` prints `enabled`, and `journalctl -u lab-heartbeat.service` shows your heartbeat line.
- `sudo nginx -t` reports the configuration test is successful.
- You can explain the difference between `start` and `enable` without looking it up.

## Why it matters

Almost every outage you will touch in a data center or NOC is a service that is `failed`, `inactive`, or misconfigured. The reflex to run `systemctl status`, pull the unit's journal with `journalctl -xeu`, validate config before restarting, and confirm with a real request is the daily bread of operations work. Writing and enabling your own unit is how you turn a manual fix into something that survives a reboot — the difference between a patch and a real fix.

## Cleanup

```bash
sudo systemctl disable --now lab-heartbeat.service
sudo rm /etc/systemd/system/lab-heartbeat.service /usr/local/bin/lab-heartbeat.sh
sudo systemctl daemon-reload
sudo nginx -t && sudo systemctl restart nginx   # confirm nginx is healthy
```

Write a short runbook of what you did in this lab and how you fixed the broken service — your future self under pressure will thank you.
