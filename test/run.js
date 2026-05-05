import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

function fail(msg) {
  console.error(msg);
  process.exit(1);
}

function log(msg) {
  console.log(msg);
}

try {
  log('Running build...');
  execSync('npm run build', { stdio: 'inherit' });
} catch (e) {
  fail('Build failed');
}

const distPath = path.resolve('dist');
const indexPath = path.join(distPath, 'index.html');

if (!fs.existsSync(indexPath)) {
  fail('Missing dist/index.html');
}
log('index.html exists');

const blogDir = path.join(distPath, 'blog');
if (!fs.existsSync(blogDir)) {
  fail('Missing dist/blog directory');
}

const blogFiles = fs.readdirSync(blogDir).filter(f => f.endsWith('.html') || fs.statSync(path.join(blogDir, f)).isDirectory());

if (blogFiles.length === 0) {
  fail('No blog pages generated');
}
log('Blog pages detected');

// Basic internal link check (very naive)
const htmlFiles = [];
function collectHtml(dir) {
  for (const file of fs.readdirSync(dir)) {
    const full = path.join(dir, file);
    if (fs.statSync(full).isDirectory()) collectHtml(full);
    else if (file.endsWith('.html')) htmlFiles.push(full);
  }
}
collectHtml(distPath);

for (const file of htmlFiles) {
  const content = fs.readFileSync(file, 'utf-8');
  const links = [...content.matchAll(/href="(\/[^"#?]+)"/g)].map(m => m[1]);
  for (const link of links) {
    const target = path.join(distPath, link);
    if (!fs.existsSync(target) && !fs.existsSync(target + '.html') && !fs.existsSync(path.join(target, 'index.html'))) {
      fail(`Broken link: ${link} in ${file}`);
    }
  }
}

log('Basic link check passed');
log('All tests passed');
