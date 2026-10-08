const fs = require('fs');

const map = {
  'Ã©': 'é',
  'Ã¨': 'è',
  'Ãª': 'ê',
  'Ã ': 'à',
  'Ã¢': 'â',
  'Ã®': 'î',
  'Ã´': 'ô',
  'Ã»': 'û',
  'Ã¹': 'ù',
  'Ã§': 'ç',
  'Ã‰': 'É',
  'Ã€': 'À',
  'Ã‡': 'Ç',
  'Å“': 'œ',
  'Å’': 'Œ',
  'â€™': "'",
  'â€˜': "'",
  'â€œ': '"',
  'â€': '"',
  'â€”': '—',
  'â€“': '–',
  'â€¦': '…',
  'â†’': '→',
  'Â§': '§',
  'Â·': '·',
  'âœ“': '✓',
  'Ã ': 'à',
};

const files = [
  'lib/features/settings/presentation/configuration_screen.dart',
  'lib/features/devices/presentation/widgets/pairing_approval_panel.dart',
  'lib/features/devices/presentation/widgets/devices_registry_panel.dart',
  'lib/features/sync/presentation/sync_screen.dart',
  'lib/features/auth/presentation/pin_login_screen.dart',
];

for (const f of files) {
  if (!fs.existsSync(f)) {
    console.log('missing', f);
    continue;
  }
  let out = fs.readFileSync(f, 'utf8');
  const keys = Object.keys(map).sort((a, b) => b.length - a.length);
  for (const k of keys) {
    out = out.split(k).join(map[k]);
  }
  fs.writeFileSync(f, out, 'utf8');
  const bad = out.includes('Ã') || out.includes('â€');
  console.log(bad ? 'still-bad' : 'ok', f);
}
