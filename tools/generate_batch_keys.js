#!/usr/bin/env node
/**
 * أداة توليد مفاتيح ترخيص عامة (offline) — بلا ارتباط برمز جهاز مسبقاً
 *
 * كل مفتاح يتفعل على "أول جهاز يدخلو"، ويولي رئيسي لهاذ الجهاز، والجهاز
 * الرئيسي هو اللي يولد بعدها مفاتيح ثانوية للأجهزة الإضافية (من داخل
 * التطبيق نفسو، بنفس آلية الثانوي الموجودة أصلاً).
 *
 * نوعين من المفاتيح:
 *   - Android : يخدم على جهازين إجمالي (1 رئيسي + 1 ثانوي)
 *   - Windows : يخدم على 4 أجهزة إجمالي (1 رئيسي + 3 ثانويين)
 *
 * الاستعمال:
 *   node generate_batch_keys.js android 10     # يولد 10 مفاتيح أندرويد
 *   node generate_batch_keys.js windows 5      # يولد 5 مفاتيح ويندوز
 *
 * ⚠️ الأسرار هنا لازم تبقى مطابقة بالضبط للي فـ
 * lib/services/license_service.dart (_genericAndroidSecret, _genericWindowsSecret).
 */
const crypto = require('crypto');

const SECRETS = {
  android: 'ZAD-DZ-2026-GENERIC-ANDROID-4mK7pL2xQ9-BATCH-SECRET',
  windows: 'ZAD-DZ-2026-GENERIC-WINDOWS-9xR3nT6vB1-BATCH-SECRET',
};

const PREFIXES = {
  android: 'ZAD-AND',
  windows: 'ZAD-WIN',
};

const platform = process.argv[2];
const count = parseInt(process.argv[3], 10);

if (!platform || !['android', 'windows'].includes(platform) || !count || count < 1) {
  console.error('الاستعمال: node generate_batch_keys.js <android|windows> <عدد_المفاتيح>');
  process.exit(1);
}

const secret = SECRETS[platform];
const prefix = PREFIXES[platform];
const maxSecondary = platform === 'android' ? 1 : 2;

console.log('');
console.log(`═══════════════════════════════════════════`);
console.log(`  🔑 مفاتيح ${platform === 'android' ? 'أندرويد' : 'ويندوز'} — كل مفتاح: 1 رئيسي + ${maxSecondary} ثانوي`);
console.log(`═══════════════════════════════════════════`);

for (let i = 0; i < count; i++) {
  // سيريال عشوائي (بلا أي علاقة برمز جهاز) — هو نفسو "الهوية" اللي كتوقع
  const serial = crypto.randomBytes(8).toString('hex').toUpperCase();

  const hmac = crypto.createHmac('sha256', secret);
  hmac.update(serial);
  const checksum = hmac.digest('hex').substring(0, 8).toUpperCase();

  const key = `${prefix}-${serial.substring(0, 4)}-${serial.substring(4, 8)}-` +
              `${serial.substring(8, 12)}-${serial.substring(12, 16)}-${checksum}`;

  console.log(`${i + 1}. ${key}`);
}

console.log('');
console.log(`تم توليد ${count} مفتاح.`);
console.log('');
