const fs = require('fs');
const lines = fs.readFileSync('cmd/main/main.mbt', 'utf8').split('\n');
let o = 0;
let inStr = false;
let inChar = false;
let inComment = false;
for (let i = 0; i < lines.length; i++) {
  let s = lines[i];
  if (o !== 0 && s.trim().startsWith('fn ') && !inStr && !inChar && !inComment) console.log('ERROR: Depth is', o, 'before fn on line', i + 1);
  for (let j = 0; j < s.length; j++) {
    if (inComment) {
      if (s[j] === '\n') inComment = false;
      continue;
    }
    if (!inStr && !inChar && s[j] === '/' && s[j + 1] === '/') {
      inComment = true;
      continue;
    }
    if (s[j] === '"' && !inChar && (j === 0 || s[j - 1] !== '\\')) inStr = !inStr;
    if (s[j] === "'" && !inStr && (j === 0 || s[j - 1] !== '\\')) inChar = !inChar;
    if (!inStr && !inChar && !inComment) {
      if (s[j] === '{') o++;
      if (s[j] === '}') o--;
    }
  }
  inComment = false;
}
console.log('Final unclosed:', o);