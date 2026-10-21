# 2BOT-company

ชุดตั้งค่า "บริษัทบอทสองตัว": บอท Claude Code **2 บัญชี** รับคำสั่งผ่าน **Discord** และช่วยกันทำงานในโปรเจกต์เดียวกัน
มีกระดานงาน, บันทึกร่วม, ระบบ "รับทราบ" เมื่อกฎเปลี่ยน และสรุปบทเรียนเป็นกฎทุกครั้งที่ปิดงาน — ให้บอทเรียนรู้สไตล์ของทีมไปเรื่อยๆ

ผู้ใช้ทำแค่ **ล็อกอินบัญชี + ก๊อป token บอท Discord + บอกโฟลเดอร์ที่ทำงาน** ที่เหลือสคริปต์ตั้งให้

## ข้างในมีอะไร
| path | คืออะไร |
|---|---|
| `setup/setup-team.ps1` | ตั้งค่าบอท 1 ตัว (รันครั้งละบอท รันซ้ำได้) — แยกบัญชี, ปลั๊กอิน Discord, สิทธิ์, token (LF), allowlist, worktree, launcher, เปิดเองตอนเปิดคอม |
| `skills/two-bot-setup/` | สกิล: วิธีตั้งค่า + ตารางแก้ปัญหา (บอทเงียบ / อ่านแต่ไม่ตอบ / ได้บัญชีผิด ฯลฯ) |
| `skills/two-bot-dev/` | สกิล: ขั้นตอนทำงานคู่สำหรับ **พัฒนาแอป** — จองงาน, branch ของใครของมัน, เทสต์, รีวิว, merge, แก้นโยบาย, `CF` |
| `templates/CLAUDE.team-code.md` | กฎทีมที่สคริปต์ใส่ท้าย `CLAUDE.md` ของโปรเจกต์ (โหมด code) |
| `templates/team/` | `BOARD.md` (ใครทำอะไร) และ `LOG.md` (บันทึกร่วม) |

## สองโหมด
- **code** (ค่าตั้งต้น): บอทแต่ละตัวมี git worktree ของตัวเอง (`../<name>-bot1`, `../<name>-bot2`) ทำบน branch `bot1/*` `bot2/*` — ไม่แก้ไฟล์ทับกัน, merge เข้า main เมื่อผู้ใช้อนุมัติ
- **video**: สองบอทใช้โฟลเดอร์โปรเจกต์เดียวกัน (ไฟล์วิดีโอใหญ่ไม่อยู่ใน git) แบ่งงานผ่านกระดาน — กฎงานวิดีโออยู่ใน repo ของโปรเจกต์นั้นเอง

## เริ่มใช้ (Windows)
ต้องมี: Claude Code (`claude`), `git`, `bun` (`npm i -g bun`), 2 บัญชี Claude, บอท Discord 2 ตัว (วิธีสร้างอยู่ในสกิล `two-bot-setup`)

```powershell
git clone https://github.com/Lskram2002v2/2BOT-company.git
cd 2BOT-company

# บอท 1 (บัญชีที่ล็อกอินอยู่แล้ว) — ก๊อป token บอท Discord ตัวที่ 1 ก่อน
powershell -ExecutionPolicy Bypass -File setup\setup-team.ps1 -Project D:\Apps\myapp -Bot 1 -DiscordUserId <ID ของคุณ> -TokenFromClipboard -Startup

# บอท 2 (บัญชีที่ 2) — ก๊อป token ตัวที่ 2 ก่อน; ครั้งแรกสคริปต์จะบอกวิธีล็อกอิน แล้วรันซ้ำ
powershell -ExecutionPolicy Bypass -File setup\setup-team.ps1 -Project D:\Apps\myapp -Bot 2 -DiscordUserId <ID ของคุณ> -TokenFromClipboard -Startup
```
เพิ่ม `-DryRun` เพื่อดูก่อนว่าจะทำอะไร · path โปรเจกต์ต้องเป็นตัวอักษรอังกฤษ (cmd อ่านภาษาไทยใน .bat เพี้ยน)
เสร็จแล้ว: เปิด `<project>\_team\bot1.bat` / `bot2.bat` (หรือรีสตาร์ทคอม) → DM บอทใน Discord

## สั่งงาน
- แท็ก**บอทเดียวต่องาน** · แท็กทั้งคู่เรื่องเดียวกัน = บอท 1 ทำ, บอท 2 ตรวจ
- "ต่อไปให้…/ห้าม…" = แก้นโยบาย → บอทอีกตัวต้องติ๊ก "รับทราบ" ใน LOG ก่อนทำงานถัดไป
- `CF` = ปิดฟีเจอร์: สรุปทุกอย่างที่สั่งแก้เป็นกฎ แล้ว merge (ถ้าอนุมัติ)
- หน้าต่างบอทต้องเปิดอยู่ (ย่อได้) และคอมห้าม sleep

## ความปลอดภัย
repo นี้เป็น public — **ห้าม commit token, `.env`, อีเมล, Discord ID, path ส่วนตัว** · token อยู่ใน `%USERPROFILE%\.claude\channels\...\.env` บนเครื่องเท่านั้น
สคริปต์อ่าน token จากคลิปบอร์ดและไม่แสดงออกจอ · บอทถูกสั่งห้ามรับ/พิมพ์ token แทนผู้ใช้
