Agent handoff: iPhone notification mirroring (ANCS)

This is a pass-off note for another agent implementing the same feature on a second peachOS machine. It describes how this actually works, what we already broke, and what not to invent. Copy the files from this repo. Do not re-derive ANCS from first principles.

Paths are from the peachOS repo unless marked live laptop.

Live overlay on Chris’s XPS (user-local, do not run provision/provision.sh):





Daemon: ~/.local/share/peachos/iphone-notify/peachos-iphone-notify



App catalog / icons: ~/.local/share/peachos/iphone-notify/peachos_ios_apps.py and .../icons/



systemd user unit: ~/.config/systemd/user/peachos-iphone-notify.service





ExecStart points at the overlay binary, not /usr/lib/peachos/...



Settings page: ~/.local/share/peachos/settings/src/iphone_page.py



Settings launcher: ~/.local/bin/peachos-settings execs the overlay main.py

Repo sources of truth:





apps/iphone-notify/peachos-iphone-notify



apps/iphone-notify/peachos_ios_apps.py



apps/iphone-notify/icons/



apps/iphone-notify/peachos-iphone-notify.service



apps/iphone-notify/org.peachos.iPhoneNotify.desktop



apps/iphone-notify/LICENSE.ancs4linux.txt



apps/settings/src/iphone_page.py



apps/settings/data/icons/iphone.svg



apps/settings/data/icons/phone_pairing.png



provision/wireplumber/51-peachos-iphone-no-audio.conf





1. What the user sees when it is working

Settings → iPhone:





Pair once. On the phone: Settings, then Bluetooth, tap this computer’s real hostname (adapter Alias). Confirm the 6-digit code. iOS then asks Allow … to Receive Your iPhone Notifications? / Share System Notifications. Accept.



After that, a status card shows the iPhone name, a green battery ring, and an honest state:





Receiving notifications (green): ANCS is subscribed. Banners will appear.



Not receiving notifications (amber): Bluetooth ACL is up, CCCD is not live yet.



Not connected (gray): bonded, but the phone is not on the link (locked, out of range, or just dropped).



Reconnecting (amber): we had ANCS and the phone just dropped.



Never lead with Paired. BlueZ Paired=true is a bond, not “the iPhone says connected” and not “we are getting banners.”



No Disconnect button. Disconnect / Device.Connect() retries A2DP and poisons the iOS bond. Forget is the only destructive action.



Lock the iPhone. Send a text. The banner should still appear on the computer. Settings may flip to Not connected while the screen is off and nothing is in flight, then back to Receiving when iOS reconnects to deliver the banner.

Desktop banners:





Gmail / iCloud Mail / Yahoo Mail / Outlook / anything ANCS marks category 6:





Bold line: sender name



Body line 1: subject



Body line 2: preview



Everything else (Messages, Instagram, Snapchat, …):





Bold line: app name



Body: notification content (Chris: Yo style)



Icons come from apps/iphone-notify/icons/ (SYSICONS filenames). Unknown apps use fallback_icon.svg. Never invent a product name from a bundle id.

Audio: this computer must not become the iPhone’s speaker, mic, or media sink.





2. What this is, technically

Apple ANCS (Apple Notification Center Service) over BLE/GATT. Spec date we followed: 2014-10-20.

Roles:





Notification Provider (NP) = the iPhone. It hosts the ANCS GATT service.



Notification Consumer (NC) = this computer. We subscribe to the phone’s characteristics.

UUIDs (hard-coded in the daemon):

ANCS service  7905f431-b5ce-4e99-a40f-4b1e122d00d0
NS  (notify)  9fbf120d-6301-42d9-8c58-25e699a21dbd   Notification Source
CP  (write)   69d1d8f3-45e1-49a8-9821-9bbdfdaad9d9   Control Point
DS  (notify)  22eac6e9-24d6-4bb5-be44-b36ace7c7bfb   Data Source
Battery       00002a19-0000-1000-8000-00805f9b34fb
CCCD          00002902-0000-1000-8000-00805f9b34fb
ATT L2CAP     PSM 0x001F

Flow once subscribed:





NS notifies an 8-byte event: event, flags, category, count, uid little-endian (<BBBBI).



We skip FLAG_PREEXISTING (bit 2). The Notification Center dump is days of old missed calls and floods Control Point so live mail/iMessage dies with InProgress.



We write GetNotificationAttributes on CP (AppID + Title + Subtitle + Message).



DS returns the attributes. We format a banner and call org.freedesktop.Notifications.Notify.



Unknown bundle ids wait up to 1.5s for GetAppAttributes so we use the real iOS display name.

Reference implementation we matched (advertisement bytes, “do not Connect()”, pairing agent only during first pair):





pzmarzly/ancs4linux (MIT; see LICENSE.ancs4linux.txt)



Confirmed live on this XPS with the unmodified ancs4linux advert: Share System Notifications actually appeared.

We did not run ancs4linux as the product. We wrote peachos-iphone-notify so we control persistence, icons, banner layout, and Settings.





3. Stack we used







Piece



What





Language



Python 3





D-Bus



PyGObject Gio + GLib on session and system bus





BlueZ advert + pairing agent



pydbus.SystemBus (object publish + RegisterAdvertisement / RegisterAgent)





BlueZ device/GATT



Gio.DBusProxy / GetManagedObjects on org.bluez





Banners



org.freedesktop.Notifications





Settings UI



GTK4 + libadwaita, same pattern as other Settings tabs





Battery ring



SVG bytes → GdkPixbuf.PixbufLoader → Gdk.Texture. Not Gtk.DrawingArea + cairo. This VM is missing python3-gi-cairo (gi._gi_cairo).





Icons



Exact files from srbinov/macOS_Tahoe_SYSICONS copied into apps/iphone-notify/icons/





Audio isolation



WirePlumber rule, not pactl mute and not AuthorizeService reject of HFP





Service



systemd user unit, Type=dbus, BusName=org.peachos.iPhoneNotify, Restart=always

Python imports the daemon needs:

import gi
gi.require_version('Gio', '2.0')
gi.require_version('GLib', '2.0')
from gi.repository import Gio, GLib
from pydbus import SystemBus
from peachos_ios_apps import format_banner, is_catalog_app

peachos_ios_apps.py must sit next to the daemon binary. systemd ExecStart the overlay copy. Restart the unit after any .py change; the running process will not reload the module.





4. Hard rules (do not “improve” these)

These were learned the hard way on this hardware (Dell XPS, BlueZ, iOS). Violating any one of them made the user forget the device on both sides and re-pair.





Never call StartDiscovery. An unconditional LE scan pins gnome-shell here (same finding as peachos-airpods-daemon). iPhone Settings → Bluetooth is a classic inquiry, not a BLE scanner.



Never call Device.Connect(). On this iPhone it retries A2DP (a2dp-source profile connect failed), iOS drops the ACL, and the next reconnect demands a full forget-and-pair. _schedule_connect is intentionally a no-op. The phone finds us via the ANCS advertisement.



Never steal BlueZ DefaultAgent except during the first pair. Opening a pairing window when a phone is already bonded makes iOS start a new pair (passkey dialog) and then refuse to come back.



Never unregister the ANCS advertisement after subscribe. Turning it off the moment StartNotify succeeded is what made iOS drop the accessory.



Keep the advert registered for the life of any iPhone session, not only while _paired() is true this millisecond. A lock-time BlueZ blip made every session look unpaired, the advert went off, and a locked phone could not find us.



Never reject HFP (0000111e / 0000111f) in AuthorizeService. Rejecting Hands-Free makes bluetoothd tear down the whole ACL (src/profile.c:ext_auth() ... audio not wanted). WirePlumber is what keeps phone audio off the desktop.



Never rewrite the adapter Alias to something like “Notify Hub”. iOS then treats the machine as a random accessory that cannot receive notifications. The name the phone lists is the adapter’s real Alias (chris-XPS-15-9530 / whatever the user set).



Never tell the user to tap this computer again in iPhone Bluetooth to “fix” a drop. That starts a new pair. Already-paired phones come back on their own if the advert is up.



Never invent a display name from a bundle id. com.linehop… → “Linehop” made LineLeap show up wrong. Wait for GetAppAttributes, or use “Notification”.



Never put desktop-entry in the Notify hints. GNOME then stacks every banner under org.peachos.iPhoneNotify (“iPhone”) instead of Messages / Gmail.



Do not use em dashes (—) in the Settings iPhone tab. User request.



Do not add a Disconnect button on the iPhone Settings card.





5. Dead ends we already walked (do not retry)







Idea



What happened





Run stock ancs4linux (1 Hz StartNotify restarter + always-on scan)



Radio busy, gnome-shell pinned





Device.Connect() to “keep it persistent”



A2DP retries, iOS bond poisoned, forget both sides





Unregister advert once subscribed (save radio)



iOS drops us, will not come back without re-pair





Pairing window / DefaultAgent on an already-bonded phone



iOS starts a new pair, then refuses the old bond





Reject HFP in the pairing agent



Entire ACL torn down





pactl mute of iPhone audio



Fragile, races Pulse/PipeWire, not needed once WirePlumber excludes the card





Outbound ATT (connect((addr, 0x001F))) on a locked phone



ECONNREFUSED (111) or reset (104). Keep poking and iOS stays down until unlock





20s unsubscribe() after Connected=false



Closed the session a locked phone needs to come back to





Tear down advert when _paired() flickers



Locked phone cannot see us





Humanize bundle ids (com.foo.bar → “Bar”)



Wrong product names





Icons from MacTahoe / peachos-darkmode-src / empty ~/codingprojects/icons



Wrong tiles. User’s files are SYSICONS names





Gtk.DrawingArea battery ring



Needs python3-gi-cairo, not installed, needs sudo





Settings status = BlueZ Connected else “Paired”



Phone said Not Connected, Settings said Paired





Show the preexisting ANCS dump on subscribe



Days-old missed calls, CP InProgress, live banners die





Empty ServiceUUIDs / random ManufacturerData on the advert



This is the working ancs4linux advert. Do not “fix” it.





6. Architecture

iPhone (ANCS GATT server)
    │  phone-initiated ACL / LE
    │  we advertise as BLE peripheral (ancs4linux advert)
    ▼
BlueZ (system bus)
    │  Device1, GattCharacteristic1, LEAdvertisingManager1
    ▼
peachos-iphone-notify  (session bus org.peachos.iPhoneNotify)
    │  format_banner() + SYSICONS path
    ▼
org.freedesktop.Notifications
    ▼
peachOS Notification Center (existing top-panel)

Settings IPhonePage
    │  GetStatus / StatusChanged / StartPairingWindow
    ▼
same daemon

Two connections we actually use, in order:





BlueZ GATT StartNotify on NS + DS. This is the happy path when iOS attached GATT (ServicesResolved=true).



Raw ATT socket to the phone’s public address, L2CAP PSM 0x001F, only when BlueZ says Connected but GATT is idle (classic slave ACL, StartNotify is a no-op). Works on an unlocked phone. A locked phone refuses it. After refuse, stop. Wait for the phone to reconnect to our advert.

We never initiate classic/LE Device.Connect().





7. Advertisement (copy this, do not redesign)

Class _Advertisement in peachos-iphone-notify is ancs4linux advertising/advertisement.py byte-for-byte. Their comment: “Simple advertisement. IDs were taken randomly.”





Type = peripheral



ServiceUUIDs = []  (empty on purpose)



IncludeTxPower = True



ManufacturerData = {0xFFFF: [0x50, 0xB0, 0x13, 0xF0]}



ServiceData = {'9999': [0x9E, 0x85, 0x39, 0x96]}



No Appearance, no SolicitUUIDs, no LocalName

The classic name iOS shows during pair comes from Adapter1.Alias, not from the LE advert.

Publish at /org/peachos/iPhoneNotify/advertisement, then:

adv_mgr = SystemBus().get('org.bluez', adapter_path)['org.bluez.LEAdvertisingManager1']
adv_mgr.RegisterAdvertisement('/org/peachos/iPhoneNotify/advertisement', {})

Keep it registered while any iPhone session exists:

def _refresh_ancs_advert(self):
    need = (
        self._pairing_open
        or bool(self._sessions)
        or bool(self._paired_sessions())
    )
    if need:
        GLib.idle_add(self._register_advertisement)
    else:
        self._unregister_advertisement()

If _adv_registered is already true, _register_advertisement returns. Do not Unregister+Register in a loop (there is a gap where iOS cannot see us).





8. Pairing (first time only)

D-Bus from Settings:





StartPairingWindow → returns 180 (seconds)



StopPairingWindow



signal Passkey(u)

What the daemon does in that window:





If _paired_sessions() is already non-empty: do not steal the agent. Keep the advert. Log that the phone will come back on its own.



Otherwise:





Save adapter Discoverable / Pairable / DiscoverableTimeout / Alias



Powered=true, Pairable=true, DiscoverableTimeout=0, Discoverable=true



Do not write Alias



Register Agent DisplayYesNo at /org/peachos/iPhoneNotify/agent and RequestDefaultAgent



Register the ANCS advert if needed



After 180s or cancel: UnregisterAgent (GNOME’s agent comes back), restore adapter, keep advert if a phone is now paired.

Pairing agent AuthorizeService: reject only A2DP/AVRCP media UUIDs in _AUDIO_UUIDS. Leave HFP alone.

After the bond:





Set Trusted=true and WakeAllowed=true on the device.



Wait SUBSCRIBE_DELAY_MS = 4000 before writing the ANCS CCCD. That write is what pops “Allow … to Receive Your iPhone Notifications?”. If you write it while the Pair dialog is still up, iOS can drop the handshake.



Later reconnects use a 250ms delay, not 4s.

Settings copy (no em dash, no “tap this computer again” as a fix):

On your iPhone, go to Settings, then Bluetooth, and tap “{adapter alias}”.

If already paired and the user clicks Pair anyway, Settings still calls StartPairingWindow (daemon will no-op the agent steal) and tells them to leave Bluetooth on.





9. Subscribe, lock screen, and persistence

This is the part that looks “randomly broken.”

What iOS actually does





Unlock + Share Notifications accepted: iOS keeps (or frequently reattaches) ANCS. BlueZ Connected=true, often ServicesResolved=true. We StartNotify. Banners flow.



Lock: iOS drops LE/GATT. Sometimes classic ACL stays (Connected=true, ServicesResolved=false). Sometimes the whole ACL goes (Connected=false). A locked iPhone refuses inbound ATT (connect((addr, 0x001F)) → errno 111 or 104).



A locked iPhone will reconnect to an advertising ANCS consumer when it has a banner to deliver. That is the real persistence model. We are the peripheral. The phone comes to us.



What we do now

On Connected=false:





Wait DISCONNECT_GRACE_SEC = 8 (iOS also blinks Connected at the end of a burst).



Then park the session: subscribed=False, close any ATT socket, cancel retries. Do not unsubscribe() / StopNotify / drop cached chars / drop the advert.



Clear _att_refused so the next inbound connection is a fresh chance.

On Connected=true rising edge:





Trusted / WakeAllowed again



Clear _att_refused



Scan ANCS chars if missing, else maybe_subscribe()

_try_subscribe:





If already subscribed, return.



If GATT bearer is down:





If _att_refused: stop. Log that we are waiting for the phone. Do not open ATT again.



Else try ATT reopen once (unlocked + BlueZ GATT idle case).



Else BlueZ StartNotify on DS then NS.



Confirm Notifying after 2s (_schedule_confirm, one timer, no 3-second spam).

ATT reopen:

sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET, socket.BTPROTO_L2CAP)
sock.settimeout(2)   # was 8; a lock refuse must not block subscribe
sock.connect((addr, 0x001F))
# ATT_MTU_REQ 517, then write CCCD 0x0001 on DS then NS

If connect fails with errno 111 / 104 / 110 (or “connection refused” / “connection reset”):

self._att_refused = True
# do not _schedule_retry

Watchdog every WATCHDOG_SEC = 8 (not 1 Hz, not 60s):





If paired, connected, not subscribed → maybe_subscribe()



_refresh_ancs_advert()

Battery: read 00002a19 once after subscribe, then at most every 300s. Hammering ReadValue on a sleepy phone contributed to flaps.

GATT bearer probe

Device.Connected can be true on classic-only. We ReadValue on battery or CP. Not connected → bearer down. Not Permitted / Not Supported → treat as up.





10. Banners and icons

All mapping lives in peachos_ios_apps.py. Daemon calls:

source, summary, body, icon = format_banner(
    app_id, fetched_app_name,
    title, subtitle, message, category)
self.daemon.show(source, summary, body, icon, replaces=...)

show():

hints = {'urgency': GLib.Variant('y', 1)}
if icon.startswith('/'):
    hints['image-path'] = GLib.Variant('s', icon)
# app_name = source (Gmail / Messages / ...)
# NO desktop-entry hint
Notify(app_name, replaces, app_icon, summary, body, [], hints, 8000)



Email layout

ANCS mail fields in practice:





Title = sender



Subtitle = subject



Message = preview

format_banner returns (app_name, sender, subject + "\n" + preview, icon).

Gmail / Inbox, com.apple.mobilemail, Outlook, Yahoo (com.yahoo.Aerogram) are layout='email'. ANCS category 6 also forces email layout for unknown mail apps.

Do not drop Title when Subtitle exists. That was the “subject + body, no name” bug.

App layout

Summary is the catalog / GetAppAttributes name. Body is title/subtitle/message joined, skipping a part that equals the app name.

Icons

Directory: apps/iphone-notify/icons/ next to peachos_ios_apps.py.

Source of the files: srbinov/macOS_Tahoe_SYSICONS. Use those exact filenames. Examples the user called out:





instagram_icon.svg



messages_icon_DEFAULTLIGHTMODE.svg



gmail_icon.png



fallback_icon.svg

lookup():





Catalog hit → mapped name + files. If GetAppAttributes sent a real name, prefer that for display but keep our icon.



Else match fetched name against catalog names.



Else {name: fetched or 'Notification', files: [], layout: 'app'} → fallback icon.

is_catalog_app(app_id) is what lets known apps banner immediately while unknown ones wait 1.5s for GetAppAttributes.

To add an app: drop the SYSICONS file in icons/, add one APPS['com.bundle.id'] = _app('Name', 'file.svg') line. Copy both files to the live overlay and restart the unit.





11. D-Bus API the Settings page uses

Session bus:





Name: org.peachos.iPhoneNotify



Path: /org/peachos/iPhoneNotify



Interface: org.peachos.iPhoneNotify

StartPairingWindow() → i
StopPairingWindow()
GetStatus() → a(ssbbuts)
signal Passkey(u)
signal StatusChanged(a(ssbbuts))

Each phone tuple:







Field



Type



Meaning





path



s



BlueZ object path





name



s



Alias / Name





connected



b



BlueZ Connected





receiving



b



ANCS subscribed (source of truth for banners)





battery



u



0 = unknown, else 0–100 from 2a19





last_banner_unix



t



time.time() of last successful Notify, else 0





last_banner_app



s



source from format_banner

Settings prefers GetStatus, merges BlueZ for Forget + Battery1 fallback, polls every 2s, and listens to StatusChanged.

Emit status (debounced 150ms) on subscribe, unsubscribe, park, battery read, banner, Connected change, device removed.





12. Settings iPhone tab

File: apps/settings/src/iphone_page.py. Wired in apps/settings/src/main.py as sidebar id iphone.

Do not use bluetooth_page.DeviceRow for the main card. That is where “Connected / Paired” came from.

PhoneStatusCard:





Left: 120px SVG ring (#34C759, red under 20% when live, gray when not). Percent is a Gtk.Label overlay, not SVG text.



Right: name (iphone-status-name), colored dot + status line, caption (last banner / waiting / not connected).



Forget iPhone.

Page-local Gtk.CssProvider so copying only iphone_page.py to the overlay is enough. This environment often cannot draw cairo DrawingAreas.

Hero text (no em dash):

See notifications from your iPhone on this computer. No jailbreak,
no companion app, and this computer will not play iPhone audio.

Hide the pair card once any phone is shown.

_is_phone() stays in bluetooth_page.py (icon, name contains iphone/ipad, or ANCS UUID in UUIDs).





13. WirePlumber (phone must not become a speaker)

File: provision/wireplumber/51-peachos-iphone-no-audio.conf

Install live to:

~/.config/wireplumber/wireplumber.conf.d/51-peachos-iphone-no-audio.conf

or the system wireplumber conf.d if that is how the machine is provisioned. Then restart WirePlumber.

It matches device.form_factor = "phone" and descriptions/media names *iPhone* / *iPad*, sets bluez5.auto-connect = [], bluez5.roles = [], device.profile = "off", and disables the nodes. Real headphones are not matched.

Do not replace this with agent-side HFP reject.





14. systemd user unit

Repo unit (apps/iphone-notify/peachos-iphone-notify.service) uses /usr/lib/peachos/iphone-notify/... for a provisioned image.

On a user-local machine (this XPS, and likely the other one if you are not running provision):

[Unit]
Description=peachOS iPhone notification mirror (ANCS)
Documentation=https://github.com/pzmarzly/ancs4linux
After=graphical-session.target

[Service]
Type=dbus
BusName=org.peachos.iPhoneNotify
ExecStart=/home/USER/.local/share/peachos/iphone-notify/peachos-iphone-notify
Restart=always
RestartSec=3

[Install]
WantedBy=graphical-session.target

mkdir -p ~/.local/share/peachos/iphone-notify
cp -a apps/iphone-notify/peachos-iphone-notify \
      apps/iphone-notify/peachos_ios_apps.py \
      ~/.local/share/peachos/iphone-notify/
cp -a apps/iphone-notify/icons ~/.local/share/peachos/iphone-notify/
chmod +x ~/.local/share/peachos/iphone-notify/peachos-iphone-notify

mkdir -p ~/.config/systemd/user
# write the unit with ExecStart pointing at the overlay
systemctl --user daemon-reload
systemctl --user enable --now peachos-iphone-notify.service

Settings overlay:

cp -a apps/settings/src/iphone_page.py ~/.local/share/peachos/settings/src/iphone_page.py
# reopen peachos-settings; it is not hot-reloaded

peachos_ios_apps.py and icons/ must be the same directory as the running binary. A daemon in ~/.local/share/peachos/iphone-notify/ will not see repo apps/iphone-notify/icons/.





15. Implement on the other machine (checklist)

Copy, do not rewrite.





Copy the whole apps/iphone-notify/ tree (daemon, peachos_ios_apps.py, icons/, desktop file, license, unit).



Copy apps/settings/src/iphone_page.py (and iphone.svg / phone_pairing.png if that Settings tree does not have them).



Confirm apps/settings/src/main.py already imports IPhonePage and has the iphone sidebar row. If not, add the same row as this repo (#0A84FF, keywords iphone notifications pairing continuity phone).



Install WirePlumber 51-peachos-iphone-no-audio.conf. Restart WirePlumber.



Install the systemd user unit with ExecStart at the actual binary. enable --now.



busctl --user introspect org.peachos.iPhoneNotify /org/peachos/iPhoneNotify org.peachos.iPhoneNotify

You must see GetStatus, StartPairingWindow, StatusChanged.



Open Settings → iPhone. Pair once. Accept Share System Notifications on the phone.



Send a text (app layout) and an email (sender / subject / preview).



Lock the phone. Send another text. Banner should still arrive. Do not tell the user to tap the computer.



Confirm Settings shows Receiving only when ANCS is actually subscribed, not merely Paired.

If the other machine already has an older daemon, overwrite overlay files and systemctl --user restart peachos-iphone-notify.service. If Settings is open, reopen it.





16. Verify / debug

systemctl --user status peachos-iphone-notify.service
journalctl --user -u peachos-iphone-notify.service -f

busctl --user call org.peachos.iPhoneNotify \
  /org/peachos/iPhoneNotify org.peachos.iPhoneNotify GetStatus

Healthy subscribe:

ANCS advertisement up as <hostname> so the iPhone can share notifications
Subscribed to ANCS on /org/bluez/hci0/dev_XX (... ) NS=True DS=True
iPhone notifications live from <name>
Banner Messages: Messages - Chris: Yo

Locked phone (expected, not a crash):

iPhone refused ATT on /org/bluez/... ( [Errno 111] Connection refused ); waiting for it to reconnect
# or
iPhone dropped the link on /org/bluez/...; advert stays up so it can come back

Then, when a banner is generated on the locked phone:

Waiting 250ms before ANCS CCCD on ...
Subscribed to ANCS ...
ANCS NS event=0 ...
Banner ...

BlueZ snapshot:

# Device1: Paired, Trusted, Connected, ServicesResolved, UUIDs contains 7905f431-...
# Adapter1: Powered, Connectable=true. Do not require Discoverable after the first pair.

GetStatus example while live:

a(ssbbuts) 1 "/org/bluez/hci0/dev_28_2D_7F_86_16_FC" "Chris iPhone" true true 82 1727… "Gmail"

While locked and idle: connected=false, receiving=false, advert still registered, session still in _sessions.





17. Code you should copy, not retype from memory



Daemon constants and D-Bus XML

See the top of apps/iphone-notify/peachos-iphone-notify (ANCS_*, IFACE_XML, PAIRING_WINDOW_SEC, SUBSCRIBE_DELAY_MS, DISCONNECT_GRACE_SEC, WATCHDOG_SEC).

Advertisement class

_Advertisement in the same file. Keep ServiceUUIDs empty.

Email / app banner

format_banner, _email_copy, _app_copy in apps/iphone-notify/peachos_ios_apps.py.

Settings status card states

live = receiving and connected
waiting = connected and not receiving
reconnecting = receiving and not connected
# else: Not connected

Ring: _ring_svg / _ring_paintable in iphone_page.py.

Notify without grouping under “iPhone”

IPhoneNotify.show() in the daemon (no desktop-entry hint, image-path for absolute icon files).





18. What not to document as user steps

Do not put these in Settings copy or in a “fix it” checklist for the user:





Tap this computer in iPhone Bluetooth



Forget both sides (unless they are already in a poisoned-bond state from an old Device.Connect() / agent-steal bug)



Enable Discoverable forever



Install a companion app on the iPhone



Jailbreak / shortcuts / ANCS apps from the App Store

The product promise: pair once, leave Bluetooth on, lock the phone, banners still show.





19. File map (copy set)

apps/iphone-notify/peachos-iphone-notify          # daemon
apps/iphone-notify/peachos_ios_apps.py            # catalog + format_banner
apps/iphone-notify/icons/*                        # SYSICONS tiles + fallback
apps/iphone-notify/peachos-iphone-notify.service  # template (fix ExecStart)
apps/iphone-notify/org.peachos.iPhoneNotify.desktop
apps/iphone-notify/LICENSE.ancs4linux.txt
apps/settings/src/iphone_page.py
apps/settings/src/main.py                         # sidebar hook (already on this tree)
apps/settings/data/icons/iphone.svg
apps/settings/data/icons/phone_pairing.png
provision/wireplumber/51-peachos-iphone-no-audio.conf

If you change behavior, change the repo files, copy to the live overlay, restart the user unit, reopen Settings. Do not edit only ~/.local/share/peachos/... or the next sync will wipe you.
