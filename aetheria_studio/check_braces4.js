const fs = require('fs');
const lines = fs.readFileSync('cmd/main/main.mbt', 'utf8').split('\n');
let o = 0;
let inStr = false;
let inChar = false;
let inComment = false;
for (let i = 0; i < lines.length; i++) {
  let s = lines[i];
  for (let j = 0; j < s.length; j++) {
    if (inComment) {
      if (s[j] === '\n') inComment = false;
      continue;
    }
    if (!inStr && !inChar && s[j] === '/' && s[j + 1] === '/') {
      inComment = true;
      break;
    }
    // basic escape support
    if (s[j] === '\\') { j++; continue; }
    if (s[j] === '"' && !inChar) inStr = !inStr;
    if (s[j] === "'" && !inStr) inChar = !inChar;
    if (!inStr && !inChar && !inComment) {
      if (s[j] === '{') { o++; }
      if (s[j] === '}') { 
         o--; 
         if (o === 0) console.log('Depth hit 0 on line', i + 1);
      }
    }
  }
  inComment = false;
}