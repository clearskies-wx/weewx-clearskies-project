# LOCAL-SKIN-TESTING.md — Development & Testing Setup

## Before modifying production skin

Always test changes locally first on a dev path to avoid breaking the live weather site.

## Development path setup

### 1. Clone the skin to a dev directory

On the weewx container:

```bash
ssh -F .local/ssh/config weewx

# Inside weewx container:
cd /etc/weewx/skins/
cp -r Belchertown Belchertown-dev
```

### 2. Update weewx.conf to use dev skin

Edit `/etc/weewx/weewx.conf` on the weewx container:

```bash
ssh -F .local/ssh/config weewx "nano /etc/weewx/weewx.conf"
```

Find the `[Belchertown]` section and add or update:

```ini
[Belchertown]
    skin_dir = /etc/weewx/skins/Belchertown-dev
    # ... other settings ...
```

**Note:** weewx config has multiple places where skin is referenced. Check:
- `[[FileGenerator]]` → `skin_path = ...`
- Top-level `[Belchertown]` section
- Or use `enable = true/false` per skin

For now, ask in a chat if unsure — configuration varies by weewx version.

### 3. Test the dev skin

Restart weewx to use the dev skin:

```bash
ssh -F .local/ssh/config weewx "systemctl restart weewx"
```

Check if it's working:

```bash
ssh -F .local/ssh/config weewx "tail -f /var/log/weewx/weewx.log"
```

Look for errors about the skin path. If weewx starts without errors, the dev skin is active.

### 4. View the output

If weewx publishes to `/var/www/weewx/`:

```bash
ssh -F .local/ssh/config ratbert "lxc exec cloud -- curl http://localhost/weather/index.html | head -20"
```

Or check from DILBERT (if weather.shaneburkhardt.com is accessible internally):

```bash
curl http://weather.shaneburkhardt.com/
```

## Making changes

1. Edit files in `/etc/weewx/skins/Belchertown-dev/` (HTML, CSS, JavaScript)
2. Force weewx to regenerate output: `ssh -F .local/ssh/config weewx "weewxd --gen-stats"`
3. Reload the browser to see changes

## Testing checklist

- [ ] Current conditions display (temperature, humidity, wind)
- [ ] Historical charts load without JavaScript errors
- [ ] Mobile layout (use browser DevTools, 375px width)
- [ ] Tablet layout (768px width)
- [ ] No 404s in browser console (missing images, CSS, JS)
- [ ] Page load time < 3 seconds (on LAN)

## Backing out changes

If the dev skin is broken and weewx won't start:

```bash
# Revert to the original production skin
ssh -F .local/ssh/config weewx "rm -rf /etc/weewx/skins/Belchertown-dev"

# Edit weewx.conf back to original Belchertown path
# (or comment out the dev path, restart weewx)

ssh -F .local/ssh/config weewx "systemctl restart weewx"
```

## Committing changes

Once dev changes are tested and verified:

1. Update the git repo (local clone at `c:\CODE\weather-belchertown\`)
2. Copy changes from dev skin back to git: `cp -r Belchertown-dev/* ./skins/Belchertown/`
3. Create a commit: `git add -A && git commit -m "Update Belchertown skin: <description>"`
4. Push to GitHub: `git push origin feature/<task-name>`
5. After PR approval, deploy to production (see [DEPLOYMENT.md](DEPLOYMENT.md))

---

## Debugging weewx output

**If weewx generates no HTML:**

1. Check weewx status: `ssh -F .local/ssh/config weewx "systemctl status weewx"`
2. Check permissions on output dir: `ssh -F .local/ssh/config weewx "ls -la /var/www/weewx/"`
3. Check logs: `ssh -F .local/ssh/config weewx "journalctl -u weewx -n 50"`

**If the skin displays but no data:**

1. Verify database has recent data: `ssh -F .local/ssh/config weewx "mysql -u weewx -p weewx -e 'SELECT dateTime, temp_out FROM archive ORDER BY dateTime DESC LIMIT 1;'"`
2. Check if weewx engine is collecting: `ssh -F .local/ssh/config weewx "cat /var/log/weewx/weewx.log | tail -20"`

---

See [CONTAINER-ACCESS.md](CONTAINER-ACCESS.md) for more SSH tips.
