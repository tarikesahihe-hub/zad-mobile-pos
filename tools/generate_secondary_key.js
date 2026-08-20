#!/usr/bin/env node
/**
 * أداة توليد مفاتيح الترخيص الثانوية (offline) لـ ZAD Mobile POS
 *
 * الاستعمال:
 *   node generate_secondary_key.js AB12-CD34-EF56
 *
 * "AB12-CD34-EF56" هو "رمز الجهاز" ديال الجهاز الثانوي (يبان فشاشة التفعيل
 * فتبويب "جهاز ثانوي"). يبعثهولك صاحب الجهاز الرئيسي، ونتا كتولّد ليه
 * مفتاح ثانوي بهاد السكريبت — بلا ما يحتاج نت أبداً، بلا ما يكون مرتبط
 * تقنياً بالرخصة الرئيسية (المزامنة الفعلية بين الأجهزة موضوع منفصل).
 *
 * ⚠️ هاد السر لازم يبقى مطابق بالضبط للي فـ
 * lib/services/license_service.dart (_secondaryHmacSecret). إلا بدلتيه هنا،
 * بدلو تما، وإلا كل المفاتيح الثانوية القديمة تبطل.
 */
const crypto = require('crypto');

const HMAC_SECRET = 'ZAD-DZ-2026-SECONDARY-7hT4nQ1xP9mK-DEVICE-SECRET';

const deviceCode = process.argv[2];

if (!deviceCode) {
  console.error('الاستعمال: node generate_secondary_key.js XXXX-XXXX-XXXX');
  process.exit(1);
}

const normalized = deviceCode.trim().toUpperCase();

const hmac = crypto.createHmac('sha256', HMAC_SECRET);
hmac.update(normalized);
const digest = hmac.digest('hex').substring(0, 16).toUpperCase();

const key = `ZAD-SEC-${digest.substring(0, 4)}-${digest.substring(4, 8)}-` +
            `${digest.substring(8, 12)}-${digest.substring(12, 16)}`;

console.log('');
console.log('رمز الجهاز (ثانوي) :', normalized);
console.log('مفتاح الترخيص الثانوي :', key);
console.log('');
