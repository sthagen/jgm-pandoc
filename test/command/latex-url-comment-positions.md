Tokens produced by retokenizing a comment inside a URL argument
should keep their original source positions.  Here the `}` and
`\zzz` come from the retokenized comment; the skipped `\zzz ` spans
columns 12-16, so the position after it is column 17.

```
% pandoc -f latex -t plain --verbose
\url{ab%cd}\zzz x
^D
2> [INFO] Skipped '\zzz ' at line 1 column 17
ab%cdx
```
