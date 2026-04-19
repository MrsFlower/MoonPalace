# MoonBit Compiler & Language Ergonomics Issue Report

## Overview
During the development of a complex multi-module desktop application (Aetheria Studio) using MoonBit and the native backend (C FFI), we encountered several critical issues related to compiler stability, language ergonomics, and unhandled panics. 

This document summarizes the bugs and unexpected behaviors we faced. We hope these insights will help improve the robustness of the MoonBit toolchain.

---

## 1. Compiler Panic: Scope & Error Handling Resolution Failure
**Issue Description:**
When refactoring old code that used the deprecated `!` error handling syntax (e.g., `@json.parse!(...)`) into the new `try...catch` or `catch { _ => ... }` syntax, the MoonBit compiler `moonc` completely crashed (Panic) instead of gracefully emitting a syntax error or type mismatch.

**Context & Trigger:**
We had deeply nested `try { ... } catch { ... }` blocks where the inner code was returning a mismatched type or an unhandled Result. In some instances, when removing the `!` suffix from a function call but forgetting to properly assign the `Result` or wrap it in a `try`, the compiler panicked with:
```text
thread 'main' panicked at 'assertion failed: ...'
```
or produced an internal AST resolution panic.

**Analysis:**
- **Is it user error?** Yes, the syntax we wrote was technically invalid under the new error handling rules.
- **Is it a compiler bug?** **Yes.** A compiler should *never* panic on invalid user input. It should gracefully catch the AST/type mismatch and emit a localized error message pointing to the specific line.

**Recommendation:**
Enhance the resilience of the type checker and error-effect resolution phases when dealing with malformed `try/catch` blocks or mixed deprecated error syntax.

---

## 2. Ergonomics & Silent Logic Bugs: String Indexing `[i]` returning ASCII Codes
**Issue Description:**
When accessing a character in a String using the index operator `s[i]`, MoonBit returns the character's internal ASCII code (or Unicode codepoint) as a numeric type (e.g., `UInt16`), rather than a String or a printable Char.

**Context & Trigger:**
In our project, we attempted to filter and rebuild a string by appending characters:
```moonbit
let mut ascii_name = ""
for j = 0; j < name.length(); j = j + 1 {
    let c = name[j]
    if c >= 32 && c <= 126 { 
        ascii_name = ascii_name + c.to_string() 
    }
}
```
**Expected:** `"Node 1"` -> `"Node_1"`
**Actual Result:** `"781111001013249"` (The ASCII values 78, 111, 100... concatenated as a string).

**Analysis:**
- **Is it user error?** Partially. MoonBit's documentation notes that `s[i]` is deprecated and `s.code_unit_at(i)` should be used, but the compiler still permits `s[i]` without a hard error, and `c.to_string()` silently succeeds by converting the `UInt16` to a decimal string.
- **Is it a compiler bug?** It's a severe **ergonomics trap**. In almost every modern high-level language (Python, JS, C#, Go), indexing a string yields a character/string, or at least converting that character to a string yields the literal character.

**Recommendation:**
1. Hard deprecate `s[i]` returning an integer, or make `Char::to_string()` distinct from `Int::to_string()` when dealing with string iteration.
2. Provide a safer, more intuitive way to slice or iterate over string characters (e.g., `for c in s` yielding actual `Char` types that can be directly appended to Strings).

---

## 3. Standard Library `moonbitlang/x/fs`: Lack of Documentation & Discovery
**Issue Description:**
When reading binary files (like PNG images) to pass through a C FFI, we initially had to write a custom C wrapper because the standard library file I/O capabilities were completely undocumented. 

**Context & Trigger:**
We eventually discovered `@fs.read_file_to_bytes(path)` and `@fs.write_bytes_to_file(path, bytes)`. However, discovering these functions and their exact signatures required manual AST inspection and guessing. Furthermore, the `moon check` tool often failed to resolve the `fs` package correctly without highly specific `.mooncakes` configurations.

**Analysis:**
- **Is it user error?** No.
- **Is it a compiler bug?** It is a tooling and documentation issue. The `moonbitlang/x` repository lacks comprehensive API references for essential native-backend modules like `fs`.

**Recommendation:**
Publish a clear, versioned API documentation for `moonbitlang/x/fs`. Ensure that the VS Code / Trae language server (LSP) can auto-complete and show type signatures for `@fs` methods seamlessly.

---

## 4. C FFI Native Backend Compilation Conflicts (Header Includes)
**Issue Description:**
When utilizing the `wasm-gc` and `native` backends simultaneously, or when trying to compile C FFI code alongside MoonBit code, the internal `tcc` compiler occasionally failed with missing standard C headers.

**Context & Trigger:**
```text
C:/Users/.../.moon/lib/runtime.c:1474: error: include file 'windows.h' not found
```
This occurred seemingly at random when switching between `moon build` and `moon check` commands, especially when the project had lingering build caches.

**Analysis:**
- **Is it user error?** No.
- **Is it a compiler bug?** **Yes.** The built-in `tcc` (Tiny C Compiler) bundled with MoonBit on Windows seems to struggle with finding standard Windows SDK headers if the environment variables aren't perfectly aligned, or if the internal MoonBit cache gets corrupted.

**Recommendation:**
Improve the reliability of the native backend C compiler toolchain on Windows. Add a `moon clean` command or ensure that `moon build --target native` properly isolates its C header paths regardless of the host system's varying MSVC/MinGW setups.

---

## Conclusion
MoonBit is an incredibly fast and promising language. The issues highlighted above—particularly the compiler panics on invalid syntax and the string indexing ergonomics—were the primary sources of friction during our development. Addressing these will significantly lower the learning curve and improve the developer experience for native application development.