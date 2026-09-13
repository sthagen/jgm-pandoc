State changes made while parsing an optional argument (which is not
a TeX group) should persist, instead of being discarded with the
sub-parse.

```
% pandoc -f latex -t native
\begin{description}
\item[\def\x{Y}k] b \x
\end{description}
^D
[ DefinitionList
    [ ( [ Str "k" ]
      , [ [ Para [ Str "b" , Space , Str "Y" ] ] ]
      )
    ]
]
```

```
% pandoc -f latex -t native
\cite[\def\x{q}]{a}\x
^D
[ Para
    [ Cite
        [ Citation
            { citationId = "a"
            , citationPrefix = []
            , citationSuffix = []
            , citationMode = NormalCitation
            , citationNoteNum = 0
            , citationHash = 0
            }
        ]
        [ RawInline (Format "latex") "\\cite[\\def\\x{q}]{a}" ]
    , Str "q"
    ]
]
```
