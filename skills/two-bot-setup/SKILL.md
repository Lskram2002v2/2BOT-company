---
name: two-bot-setup
description: >-
  ตั้งค่าบอท Claude Code 2 ตัว (2 บัญชี) ให้รับคำสั่งผ่าน Discord และทำงานในโปรเจกต์เดียวกัน — สร้างบอท Discord, แยกบัญชีที่ 2,
  ใส่ token, เปิดเองตอนเปิดคอม และแก้ปัญหาบอทเงียบ/ไม่ตอบ ใช้เมื่อผู้ใช้จะตั้งบอทคู่ในโฟลเดอร์ใหม่ เพิ่มบัญชีที่ 2 หรือบอทออนไลน์แต่ไม่ตอบ
---

# ตั้งค่าบอทคู่ (two-bot-setup)

ชุดเครื่องมือ: repo `2BOT-company` (`setup/setup-team.ps1`, `templates/`, `skills/`) — สคริปต์ทำทุกอย่างที่ทำซ้ำได้ ผู้ใช้ทำเองแค่ ล็อกอิน + ก๊อป token
**Claude ห้ามรับ/พิมพ์/เขียน token หรือรหัสผ่านแทนผู้ใช้** — ให้ผู้ใช้ก๊อป token เข้าคลิปบอร์ดแล้วรันสคริปต์ด้วย `-TokenFromClipboard` เอง
ถ้าผู้ใช้เผลอส่ง token ในแชท: บอกให้ Reset Token ทันที (ประวัติแชทถูกเก็บ) แล้วใช้ token ใหม่

## โครงสร้าง
| | บอท 1 | บอท 2 |
|---|---|---|
| บัญชี Claude | บัญชีหลัก (config `~\.claude`) | บัญชีที่ 2 (config `~\.claude-acc2` ผ่าน `CLAUDE_CONFIG_DIR`) |
| บอท Discord | ตัวที่ 1 (`DISCORD_STATE_DIR` ของตัวเอง) | ตัวที่ 2 — **token ห้ามใช้ซ้ำ** ระหว่างบอทที่รันพร้อมกัน |
| ที่ทำงาน | code: worktree `../<name>-bot1` · video: โฟลเดอร์โปรเจกต์ | code: worktree `../<name>-bot2` · video: โฟลเดอร์เดียวกัน |
| ใช้ร่วมกัน | ความจำ (junction `~\.claude-acc2\projects` → `~\.claude\projects`), handoff, ไฟล์ทีม `BOARD.md` / `LOG.md` | |

## ขั้นตอน (ผู้ใช้ทำ — Claude อธิบายทีละข้อ)
1. **บอท Discord** (ต่อบอทหนึ่งตัว): https://discord.com/developers/applications → New Application → **Bot** → เปิด **Message Content Intent** → Save
   → **OAuth2 > URL Generator**: scope `bot` + สิทธิ์ View Channels, Send Messages, Send Messages in Threads, Read Message History, Attach Files, Add Reactions
   → เปิดลิงก์ เชิญเข้าเซิร์ฟเวอร์ของผู้ใช้ → กลับมาหน้า Bot → **Reset Token → Copy** (อย่าวางที่ไหน)
2. **Discord user ID ของผู้ใช้**: Discord > Settings > Advanced > Developer Mode → คลิกขวาที่ชื่อตัวเอง → Copy User ID
3. **รันสคริปต์** (PowerShell, ทีละบอท):
   ```
   powershell -ExecutionPolicy Bypass -File <kit>\setup\setup-team.ps1 -Project <โฟลเดอร์> -Bot 1 -DiscordUserId <ID> -TokenFromClipboard -Startup
   ```
   บอท 2: ก๊อป token ของบอทตัวที่ 2 แล้วรันเหมือนเดิมด้วย `-Bot 2` — ครั้งแรกสคริปต์จะบอกให้ล็อกอิน:
   `set CLAUDE_CONFIG_DIR=%USERPROFILE%\.claude-acc2 && claude` → `/login` (**ใช้หน้าต่าง incognito** ถ้าเบราว์เซอร์ล็อกอิน claude.ai บัญชีแรกค้าง ไม่งั้นได้บัญชีเดิม)
   → `/status` เช็กอีเมล → `/exit` → รันสคริปต์ซ้ำ (รันซ้ำได้เสมอ ข้ามสิ่งที่มีแล้ว)
   `-DryRun` = ดูว่าจะทำอะไรโดยไม่แตะเครื่อง · โปรเจกต์ที่มีบอท Discord อยู่แล้ว ใช้ `-StateDir <โฟลเดอร์เดิม>` แทน token ใหม่
4. **เปิดบอท**: ดับเบิลคลิก `<team>\botN.bat` (หรือรีสตาร์ท/ล็อกอิน Windows ถ้าใส่ `-Startup`) → DM บอทใน Discord

## ใช้งาน
- บอททำงานได้**เฉพาะตอนหน้าต่าง terminal ของมันเปิดอยู่** (ย่อได้ ห้ามปิด) และคอมต้องไม่ sleep
- บอทอ่านอย่างเดียวไม่ตอบ + ขึ้นเขียว ได้ถ้ามีโปรแกรมอื่นถือ token อยู่ (เช่น แอป Claude เดสก์ท็อปที่เปิดปลั๊กอิน Discord ด้วย) — ทำงานจริงเฉพาะ session ที่เปิดด้วย `--channels`
- บัญชีติดลิมิต: บอทยังเขียวและอ่านข้อความได้ (ปลั๊กอินไม่ใช้โควตา) แต่ไม่ตอบ → ใช้อีกบอท + handoff; `/usage` ในหน้าต่างบอทบอกเวลารีเซ็ต
- เลิกเปิดอัตโนมัติ: `Win+R` → `shell:startup` → ลบทางลัด `<name> Bot N`
- บอทแต่ละตัวอ่าน CLAUDE.md ครั้งเดียวตอนเปิด — กฎเปลี่ยน ให้บอกบอทว่า "อ่าน CLAUDE.md กับ LOG ใหม่" หรือเปิดใหม่ (สกิลอ่านใหม่ทุกครั้งที่ใช้)

## 🛑 แก้ปัญหา (บทเรียนจากการตั้งจริง — เช็กตามลำดับ)
| อาการ | สาเหตุ | แก้ |
|---|---|---|
| หน้าต่างบอท 2 ขึ้นบัญชีแรก / โฟลเดอร์ config บัญชี 2 ว่าง | `.bat` มีภาษาไทย → cmd (chcp 65001) อ่านเพี้ยน ข้ามบรรทัด `set` | `.bat` ต้อง ASCII ล้วน (สคริปต์เขียนให้แล้ว); path โปรเจกต์ต้อง ASCII |
| บอทออฟไลน์ (จุดเทา) ทั้งที่หน้าต่างเปิด | log ปลั๊กอิน: `DISCORD_BOT_TOKEN required` | `.env` เป็น CRLF (เขียนด้วย PowerShell `Set-Content`) → ต้อง LF; หรือ token ว่าง — รันสคริปต์ซ้ำ (แก้ CRLF ให้เอง) |
| `/mcp` ไม่มี discord / ขึ้น failed หลังติดตั้งปลั๊กอิน | session เปิดก่อนติดตั้ง | `/reload-plugins` หรือปิดแล้วเปิดหน้าต่างใหม่ |
| บอทอ่าน (ขึ้นว่าอ่านแล้ว) แต่ไม่ตอบ | บัญชีนั้นยังไม่อนุญาตเครื่องมือ Discord → ค้างรอกด Allow ในหน้าต่าง | settings ของบัญชีต้องมี `"permissions": {"allow": ["mcp__plugin_discord_discord"]}` (สคริปต์ใส่ให้) แล้วเปิดใหม่ |
| ตอบกลับเป็นรหัสจับคู่ (pairing) | ID ผู้ใช้ไม่อยู่ใน allowlist | รันสคริปต์ด้วย `-DiscordUserId` — **ห้ามใช้ `/discord:access` / `/discord:configure` ในบอทที่ไม่ใช่ตัว default** (เขียนลงโฟลเดอร์ของบอท default เสมอ) |
| บอททักในห้องเซิร์ฟเวอร์ไม่ตอบ | ห้องต้อง @แท็กบอท และต้องเพิ่มห้องใน `groups` ของ access.json | ใช้ DM หรือเพิ่ม `"groups": {"<channel id>": {"requireMention": true, "allowFrom": ["<user id>"]}}` |
| ชื่อไฟล์ทางลัด Startup กลายเป็น `???????` | WScript เก็บได้แค่ ANSI | ทางลัดต้องชี้ path ASCII (สคริปต์ชี้ `<team>\botN.bat`) |
| ไม่รู้ว่าบอทค้างอะไร | — | ดูหน้าต่างบอท; log ปลั๊กอิน: `%LOCALAPPDATA%\claude-cli-nodejs\Cache\<project-path>\mcp-logs-plugin-discord-discord\` ; ทดสอบตรง: `set CLAUDE_CONFIG_DIR=… && claude mcp list` (ต้องขึ้น `plugin:discord:discord ✔ Connected`) |

เช็กบัญชีของแต่ละ config โดยไม่เปิดหน้าต่าง: อ่าน `oauthAccount.emailAddress` ใน `~\.claude.json` (บอท 1) / `~\.claude-acc2\.claude.json` (บอท 2)
