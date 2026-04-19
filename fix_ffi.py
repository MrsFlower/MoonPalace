import os
import re

filepath = r'c:\Users\15866\Documents\codeheaven\moonbit-game\moonpalace\aetheria_workshop\src\raylib\raylib.mbt'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

def replacer(match):
    name = match.group(1)
    args = match.group(2)
    ret = match.group(3)
    symbol = match.group(4)
    if ret is None:
        ret = ""
    return f'fn {name}({args}) {ret} = "ffi" "{symbol}"'

# Matches: extern "C" fn my_func(a: Int) -> Int = "my_func"
new_content = re.sub(r'extern\s+"C"\s+fn\s+([a-zA-Z0-9_]+)\s*\((.*?)\)\s*(->\s*[a-zA-Z0-9_\[\]\(\)\s,]+)?\s*=\s*"(.*?)"', replacer, content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_content)
print("FFI updated.")
