#!/usr/bin/env node
/**
 * أداة توليد مفاتيح الترخيص مدى الحياة (offline) لـ ZAD Mobile POS
 *
 * الاستعمال:
 *   node generate_lifetime_key.js AB12-CD34-EF56
 *
 * "AB12-CD34-EF56" هو "رمز الجهاز" اللي كيبان للزبون فشاشة التفعيل فالتطبيق
 * (بعد ما تخلص 15 يوم التجربة). يبعثهولك، ونتا كتولّد ليه المفتاح بهاد
 * السكريبت وتبعتهولو، وهو كيدخلو فالتطبيق — بلا ما يحتاج نت أبداً.
 *
 * ⚠️ هاد السر لازم يبقى مطابق بالضبط للي فـ
 * lib/services/license_service.dart (_hmacSecret). إلا بدلتيه هنا، بدلو
 * تما، وإلا كل المفاتيح القديمة اللي بعتيتيها للزبائن تبطل.
 */
const crypto = require('crypto');

const HMAC_SECRET = 'ZAD-DZ-2026-8f3K9pQ2mN7vR4xL-LIFETIME-SECRET';

const deviceCode = process.argv[2];

if (!deviceCode) {
  console.error('الاستعمال: node generate_lifetime_key.js XXXX-XXXX-XXXX');
  process.exit(1);
}

const normalized = deviceCode.trim().toUpperCase();

const hmac = crypto.createHmac('sha256', HMAC_SECRET);
hmac.update(normalized);
const digest = hmac.digest('hex').substring(0, 16).toUpperCase();

const key = `ZAD-LIFE-${digest.substring(0, 4)}-${digest.substring(4, 8)}-` +
            `${digest.substring(8, 12)}-${digest.substring(12, 16)}`;

console.log('');
console.log('رمز الجهاز :', normalized);
console.log('مفتاح الترخيص (مدى الحياة):', key);
console.log('');
