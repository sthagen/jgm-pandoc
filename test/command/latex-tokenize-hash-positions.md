Source positions of tokens following `##` should not be off by one.
The skipped `\zzz ` spans columns 4-8, so the position after it is
column 9.

```
% pandoc -f latex -t plain --verbose
## \zzz hi
^D
2> [INFO] Parsing unescaped '#' at line 1 column 1
2> [INFO] Parsing unescaped '#' at line 1 column 2
2> [INFO] Skipped '\zzz ' at line 1 column 9
## hi
```
