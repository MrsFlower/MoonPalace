const fs = require('fs');
const s = fs.readFileSync('cmd/main/main.mbt', 'utf8');
let o = 0;
let inStr = false;
let inChar = false;
let inComment = false;
for (let i = 0; i < s.length; i++) {
  if (inComment) {
    if (s[i] === '\n') inComment = false;
    continue;
  }
  if (!inStr && !inChar && s[i] === '/' && s[i+1] === '/') {
    inComment = true;
    continue;
  }
  if (s[i] === '"' && !inChar && (i === 0 || s[i-1] !== '\\')) inStr = !inStr;
  if (s[i] === "'" && !inStr && (i === 0 || s[i-1] !== '\\')) inChar = !inChar;
  if (!inStr && !inChar && !inComment) {
    if (s[i] === '{') { o++; console.log(i, 'open', o); }
    if (s[i] === '}') { o--; console.log(i, 'close', o); }
  }
}
console.log('unclosed:', o);