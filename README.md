# sector-lisp-on-c64

2026-05-11

- <https://inchoatemiscellany.nekoweb.org/projects/c64/c64-ui.html> - asm .prg is fast, bas .prg is slow from From <https://github.com/floooh/tiny8bit>
- <https://stigc.dk/c64/basic/> - Paste the .bas into the text window below the C64 screen

- There's a problems with lines longer than 80 characters



---

Develop a lisp based on the friendly version of SectorLisp that runs on the Commodore 64

There are a number of things to consider:

1. Find one that exists
2. Develop one based on the friendly (includes `DEFINE`) polyglot C/Javascript code in Justine Tunney's https://justine.lol/sectorlisp2/
3. Base it on the assembler code
4. Implement with C64 BASIC.
5. Implement with 6502 assember

I like this sectorlisp. It's basic but can implemnt a 1970s style pedagogic symbolic database with query capabilities.
I like the idea of implimenting this in BASIC rather than 6502 assemblers because it's more widly understood.

I've included Justine's `lisp.js` to demonstrate one way to implement this minimal lisp. It can be read as either C or Javascript.

I've also included the Justine's assembler version

Also, this is the link to Justine's blog article about the friendly sectorlisp implementation: https://justine.lol/sectorlisp2/
