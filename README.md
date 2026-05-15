# 🚀 Laravel Deploy Pro

[![Version](https://img.shields.io/badge/version-4.0-blue.svg)](https://github.com/salehye/laravel-deploy-script)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-5.0+-yellow.svg)](https://www.gnu.org/software/bash/)
[![Laravel](https://img.shields.io/badge/Laravel-9.x%2F10.x-red.svg)](https://laravel.com)

سكربت احترافي لنشر تطبيقات Laravel على VPS مع Zero Downtime، SSL تلقائي، ودعم متعدد الدومينات.

## ✨ الميزات

| الميزة | الوصف |
|--------|-------|
| 🚀 | **نشر سريع** - السكربت يعمل تلقائياً بنقرة واحدة |
| 🌐 | **دعم متعدد الدومينات** - إضافة عدة دومينات لنفس المشروع |
| 🔒 | **SSL تلقائي** - شهادة Let's Encrypt مجانية |
| 📦 | **Zero Downtime** - نشر دون توقف الخدمة |
| 🗄️ | **قواعد بيانات متعددة** - MySQL, PostgreSQL, MariaDB |
| ⚙️ | **خيارات مرنة** - تخصيص PHP، الموارد، والإضافات |
| 🔄 | **نشر تلقائي** - Webhook + GitHub Actions |
| 📊 | **مراقبة الأداء** - إحصائيات النظام والمواقع |
| 💾 | **نسخ احتياطي** - تلقائي يومي |
| 🛡️ | **حماية متقدمة** - Fail2ban, ModSecurity, UFW |
| ⚙️ | **إدارة كاملة** - تعديل وحذف المشاريع بسهولة |
| 🛠️ | **أدوات إضافية** - وضع الصيانة، مستعرض السجلات، إعداد Swap |
| 📦 | **بيئة التطوير** - تثبيت Docker, Node.js, NPM تلقائياً |

## 📋 المتطلبات الأساسية

- VPS يعمل بـ Ubuntu 20.04 / 22.04 / 24.04
- صلاحيات `root` أو مستخدم مع `sudo`
- اتصال بالإنترنت

## 🚀 التثبيت السريع

### طريقة التنزيل المباشر:

```bash
curl -sSL https://raw.githubusercontent.com/salehye/laravel-deploy-script/main/deploy.sh -o deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

### طريقة Git:

```bash
git clone https://github.com/salehye/laravel-deploy-script.git
cd laravel-deploy-script
chmod +x deploy.sh
sudo ./deploy.sh
```

## 📖 الاستخدام

بعد تشغيل السكربت، اتبع التعليمات التفاعلية:

1. أدخل اسم المشروع
2. أضف الدومينات (يمكنك إضافة عدة دومينات)
3. اختر إصدار PHP المناسب
4. اختر نوع قاعدة البيانات
5. أدخل رابط GitHub (اختياري)
6. أكد المعلومات وانتظر حتى الانتهاء

## 🛠️ الأوامر السريعة

```bash
# نشر مشروع جديد
sudo ./deploy.sh

# تحديث مشروع موجود
sudo deploy-{PROJECT_NAME}

# إدارة النسخ الاحتياطي
sudo ./scripts/backup.sh

# مراقبة الأداء
sudo ./scripts/monitor.sh

# تثبيت Docker
sudo ./scripts/install-docker.sh
```

## 📁 هيكل الملفات بعد النشر

```
/var/www/example.com/
├── current/              # الإصدار الحالي (symlink)
├── releases/             # الإصدارات السابقة
│   ├── 20240101_120000/
│   └── 20240102_120000/
├── shared/               # الملفات المشتركة
│   ├── .env
│   └── storage/
├── logs/                 # سجلات الموقع
│   ├── php-error.log
│   └── nginx-error.log
└── .deploy-info          # معلومات النشر
```

## 🛡️ الأمان (Security)

تم تصميم السكربت مع التركيز على الأمان:
- **التحقق من المدخلات:** يتم فحص أسماء المشاريع والدومينات لمنع حقن الأوامر (Command Injection).
- **صلاحيات الملفات:** يتم تعيين صلاحيات صارمة للملفات الحساسة مثل `.env` (640).
- **إدارة كلمات المرور:** يتم إنشاء كلمات مرور عشوائية قوية لكل مشروع.
- **حماية العملية:** استخدام متغيرات البيئة المؤقتة للتعامل مع كلمات مرور قاعدة البيانات لتجنب ظهورها في سجل العمليات.
- **رؤوس الأمان:** إعداد Nginx يتضمن حماية ضد XSS و Clickjacking و Sniffing.

## 🤝 المساهمة

نرحب بمساهماتكم! يرجى قراءة [دليل المساهمة](CONTRIBUTING.md).

## 📄 الرخصة

MIT License - اطلع على [LICENSE](LICENSE) للمزيد.

## ⭐ الدعم

إذا أعجبك المشروع، لا تنسى وضع نجمة ⭐
