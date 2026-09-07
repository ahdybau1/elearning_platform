const fs = require('node:fs');
const path = require('node:path');
for (const app of ['admin_app', 'student_app']) {
  const config = fs.readFileSync(path.join(app, '.env.public'), 'utf8');
  const entries = Object.fromEntries(config.trim().split(/\r?\n/).map(line => {
    const at = line.indexOf('=');
    if (at < 1) throw Error('Invalid public configuration');
    return [line.slice(0, at), line.slice(at + 1)];
  }));
  if (Object.keys(entries).sort().join(',') !== 'SUPABASE_ANON_KEY,SUPABASE_URL') throw Error(app + ': unexpected public field');
  if (!entries.SUPABASE_ANON_KEY.startsWith('sb_publishable_')) throw Error(app + ': public key required');
  if (!/^https:\/\/[a-z]{20}\.supabase\.co$/.test(entries.SUPABASE_URL)) throw Error(app + ': invalid project URL');
  const pubspec = fs.readFileSync(path.join(app, 'pubspec.yaml'), 'utf8');
  if (/^\s*-\s*\.env\s*$/m.test(pubspec)) throw Error(app + ': private .env is packaged');
  if (process.argv.includes('--built')) {
    const assets = path.join(app, 'build/web/assets');
    if (fs.existsSync(path.join(assets, '.env'))) throw Error(app + ': private .env found in build');
    if (fs.readFileSync(path.join(assets, '.env.public'), 'utf8') !== config) throw Error(app + ': stale public config in build');
  }
}
console.log('PASS: only validated public Supabase configuration is packaged');
