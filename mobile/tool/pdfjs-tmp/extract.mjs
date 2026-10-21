import fs from 'node:fs';
import { getDocument } from 'pdfjs-dist/legacy/build/pdf.mjs';

const data = new Uint8Array(fs.readFileSync('../invoice-source.pdf'));
const doc = await getDocument({ data, verbosity: 0 }).promise;
console.log('pages', doc.numPages);
for (let i = 1; i <= doc.numPages; i++) {
  const page = await doc.getPage(i);
  const content = await page.getTextContent();
  const line = content.items.map((item) => item.str).join(' | ');
  console.log('\n--- page', i, '---\n');
  console.log(line);
}
