Tests corresponding to the examples in the LaTeX usrguide
(<https://www.latex-project.org/help/documentation/usrguide.pdf>).

§2.2: the `\chapter`-like example with `s o m`:

```
% pandoc -f latex -t plain
\NewDocumentCommand\mychapter{s o m}
  {\IfBooleanTF{#1}{star: #3}{normal: \IfNoValueTF{#2}{#3}{#2} / #3}\par}
\mychapter{One}
\mychapter*{Two}
\mychapter[Short]{Long}
^D
normal: One / One

star: Two

normal: Short / Long
```

§2.3: spaces around the environment name are ignored:

```
% pandoc -f latex -t plain
\NewDocumentEnvironment{ foo }{}{[}{]}
\begin{foo}x\end{foo}
^D
[x]
```

§2.5: optional arguments may safely be nested:

```
% pandoc -f latex -t plain
\NewDocumentCommand\foo{om}{I grabbed (#1) and (#2)}
\NewDocumentCommand\baz{o}{#1-#1}
\foo[\baz[stuff]]{more stuff}
^D
I grabbed (stuff-stuff) and (more stuff)
```

§2.5: the default for `O` can be the result of grabbing another
argument:

```
% pandoc -f latex -t plain
\NewDocumentCommand\foo{O{#2} m}{opt=#1, mand=#2.}
\foo{A}

\foo[B]{A}
^D
opt=A, mand=A.

opt=B, mand=A.
```

§2.6: spaces before optional arguments are allowed by default,
but not with the `!` modifier:

```
% pandoc -f latex -t plain
\NewDocumentCommand\foobar{m o}{(#1|#2)}
\NewDocumentCommand\foobang{m !o}{(#1|#2)}
\foobar{arg1} [arg2]

\foobang{arg1} [arg2]
^D
(arg1|arg2)

(arg1|-NoValue-) [arg2]
```

§2.8: `\IfNoValueTF`:

```
% pandoc -f latex -t plain
\NewDocumentCommand\foo{o m}
  {%
    \IfNoValueTF {#1}%
      {just #2}%
      {both #1 and #2}}
\foo{m}, \foo[o]{m}
^D
just m, both o and m
```

§2.8: the `\IfBlankTF` example, including the effect of `!` on
the last `\foo`:

```
% pandoc -f latex -t plain
\NewDocumentCommand\foo{m!o}{\par #1:
  \IfNoValueTF{#2}
    {No optional}%
    {%
       \IfBlankTF{#2}
         {Blanks in or empty}%
         {Real content in}%
    }%
  \space argument!}
\foo{1}[bar] \foo{2}[ ] \foo{3}[] \foo{4}[\space] \foo{5} [x]
^D
1: Real content in argument!

2: Blanks in or empty argument!

3: Blanks in or empty argument!

4: Real content in argument!

5: No optional argument! [x]
```

§2.8: `\IfBooleanTF`:

```
% pandoc -f latex -t plain
\NewDocumentCommand\foo{sm}
  {%
    \IfBooleanTF {#1}%
      {with star: #2}%
      {without star: #2}}
\foo{a}, \foo*{b}
^D
without star: a, with star: b
```

§2.9: the `=` modifier (key–value interface for an argument) is
accepted:

```
% pandoc -f latex -t plain
\DeclareDocumentCommand\mycaption{s ={short-text} +O{#3} +m}{[#2|#3]}
\mycaption{Text}
\mycaption[Short]{Long}
^D
[Text|Text] [Short|Long]
```

§2.10: `\SplitArgument` splits into a fixed number of parts,
trimming spaces, padding with `-NoValue-`:

```
% pandoc -f latex -t plain
\NewDocumentCommand\InternalFunctionOfThreeArguments{mmm}{1=#1, 2=#2, 3=#3.}
\NewDocumentCommand\foo{>{\SplitArgument{2}{;}} m}
  {\InternalFunctionOfThreeArguments#1}
\foo{a ; b ; c}

\foo{a;b}
^D
1=a, 2=b, 3=c.

1=a, 2=b, 3=-NoValue-.
```

§2.10: a processor applied to an `e`-type argument applies to
all of its arguments:

```
% pandoc -f latex -t plain
\NewDocumentCommand\foo{ >{\TrimSpaces} e{_^} }
  { [#1](#2) }
\foo_{ a }^{ b }
^D
[a](b)
```

§2.10: `\SplitList` and `\ProcessList`:

```
% pandoc -f latex -t plain
\NewDocumentCommand\SomeDocumentCommand{m}{<#1>}
\NewDocumentCommand\foo{>{\SplitList{;}} m}
  {\ProcessList{#1}{\SomeDocumentCommand}}
\foo{a; b ;c}
^D
<a><b><c>
```

§2.10: `\ProcessList` with arbitrary tokens expecting one
argument:

```
% pandoc -f latex -t plain
\NewDocumentCommand\SomeDocumentCommand{m}{<#1>}
\NewDocumentCommand\foo{>{\SplitList{;}} m}
  {\ProcessList{#1}{Abc \SomeDocumentCommand}}
\foo{a;b}
^D
Abc <a>Abc <b>
```

§2.10: `\ReverseBoolean`:

```
% pandoc -f latex -t plain
\NewDocumentCommand\foo{>{\ReverseBoolean} s m}
  {%
    \IfBooleanTF#1%
      {without star: #2}%
      {with star: #2}}
\foo{a}, \foo*{b}
^D
without star: a, with star: b
```

§2.10: `\TrimSpaces`:

```
% pandoc -f latex -t plain
\NewDocumentCommand\foo{>{\TrimSpaces} m}{[#1]}
\foo{ hello world }
^D
[hello world]
```

§2.11: the `b` argument type grabs the body of the environment;
spaces are trimmed at both ends:

```
% pandoc -f latex -t html
\NewDocumentEnvironment{twice}{O{\ttfamily} +b}
  {#2#1#2} {}
\begin{twice}[\itshape]
  Hello world!
\end{twice}
^D
<p>Hello world!<em>Hello world!</em></p>
```

§2.12–2.13: `\NewExpandableDocumentCommand`, wrapping
`\multicolumn` in a tabular cell:

```
% pandoc -f latex -t plain
\NewExpandableDocumentCommand\MyMultiCol{m}{\multicolumn{3}{c}{#1}}
\begin{tabular}{lcr}
a & b & c \\
\MyMultiCol{stuff} \\
\end{tabular}
^D
+:----+:---:+----:+
| a   | b   | c   |
+-----+-----+-----+
| stuff           |
+-----------------+
```

§2.16: the `c` argument type grabs the body of the environment
verbatim; it is typeset with spaces as visible spaces (U+2423):

```
% pandoc -f latex -t plain
\NewDocumentEnvironment{MyVerbatim}{!O{\ttfamily} c}
  {\begin{center} #1 #2\end{center}} {}
\begin{MyVerbatim}[\ttfamily\itshape]
  % Some code is shown here
  $y = mx + c$
\end{MyVerbatim}
^D
␣␣%␣Some␣code␣is␣shown␣here
␣␣$y␣=␣mx␣+␣c$
```

§3: `\NewCommandCopy` copies a definition, so the original can
be redefined in terms of the copy:

```
% pandoc -f latex -t plain
\NewDocumentCommand\hi{}{Hello!}
\NewCommandCopy\hiorig\hi
\RenewDocumentCommand\hi{}{\hiorig{} And again: \hiorig}
\hi
^D
Hello! And again: Hello!
```

§4: `\UseName` turns a string into a csname and executes it:

```
% pandoc -f latex -t plain
\NewDocumentCommand\hello{}{Hello!}
\UseName{hello}
^D
Hello!
```

§4: `\ExpandArgs{c}` constructs a command name for
`\NewDocumentCommand`:

```
% pandoc -f latex -t plain
\NewDocumentCommand\newnoter{m}
  {\ExpandArgs{c}\NewDocumentCommand{#1}{m}{#1 note: ##1.}}
\newnoter{todo}
\todo{fix this}
^D
todo note: fix this.
```

§4: `\ExpandArgs{cc}` with `\NewCommandCopy`, copying a command
by string name:

```
% pandoc -f latex -t plain
\NewDocumentCommand\savebyname{m}
  {\ExpandArgs{cc}\NewCommandCopy{saved#1}{#1}}
\NewDocumentCommand\greeting{}{Hello!}
\savebyname{greeting}
\RenewDocumentCommand\greeting{}{Goodbye!}
\greeting{} \UseName{savedgreeting}
^D
Goodbye! Hello!
```

§4: `\ExpandArgs{Nc}`:

```
% pandoc -f latex -t plain
\NewDocumentCommand\target{}{found}
\ExpandArgs{Nc}\NewCommandCopy\mycopy{target}
\mycopy
^D
found
```

§5: the `\fpeval` example:

```
% pandoc -f latex -t plain
\LaTeX{} can now compute: $\fpeval{sin(3.5)/2 + 2e-3}$.
^D
LaTeX can now compute: −0.1733916138448099.
```

§5: assorted `\fpeval` operations:

```
% pandoc -f latex -t plain
\fpeval{pi}, \fpeval{sqrt 2}, \fpeval{exp(0)}, \fpeval{max(1,2,3)},
\fpeval{fact(5)}, \fpeval{abs(-4)}, \fpeval{round(2.345,2)},
\fpeval{floor(2.7)}, \fpeval{ceil(2.2)}, \fpeval{trunc(-2.7)}
^D
3.141592653589793, 1.414213562373095, 1, 3, 120, 4, 2.34, 2, 3, -2
```

§5: the `\inteval` example:

```
% pandoc -f latex -t plain
\LaTeX{} can now compute: The sum of the numbers is $\inteval{1 + 2 + 3}$.
^D
LaTeX can now compute: The sum of the numbers is 6.
```

§6: `\expandableinput` reads a file like `\input`:

```
% pandoc -f latex -t html
Before. \expandableinput{command/bar}
^D
<p>Before. <em>hi there</em></p>
```

§7: `\MakeUppercase`, `\MakeLowercase`, `\MakeTitlecase`:

```
% pandoc -f latex -t plain
\MakeUppercase{hello WORLD ßüé}

\MakeLowercase{hello WORLD ßüé}

\MakeTitlecase{hello WORLD ßüé}
^D
HELLO WORLD SSÜÉ

hello world ßüé

Hello WORLD ßüé
```

§7: the `words` option of `\MakeTitlecase`:

```
% pandoc -f latex -t plain
\MakeTitlecase[words = first]{some words}
\MakeTitlecase[words = all]{some words}
^D
Some words Some Words
```

§7: mathematical content is excluded from case changing, and
`\NoCaseChange` excludes its argument:

```
% pandoc -f latex -t markdown
\MakeUppercase{Some text $y = mx + c$}

\MakeUppercase{\NoCaseChange{iPhone}}
^D
SOME TEXT $y = mx + c$

iPhone
```

§7: `\DeclareTitlecaseExclusions`:

```
% pandoc -f latex -t plain
\DeclareTitlecaseExclusions{a,an,and,on,of,the}
\MakeTitlecase[words = all]{Of mice and men}

\MakeTitlecase[words = all]{The mill on the floss}

\MakeTitlecase[words = all]{The comedy of errors}
^D
Of Mice and Men

The Mill on the Floss

The Comedy of Errors
```

§7: `\DeclareUppercaseMapping` etc. are parsed and ignored:

```
% pandoc -f latex -t plain
\DeclareUppercaseMapping{"01F0}{\v{J}}
\DeclareLowercaseMapping[xx]{"0049}{\i}
Done.
^D
Done.
```

§8: `\textsubscript` and `\textsuperscript`:

```
% pandoc -f latex -t html
A\textsubscript{low} and B\textsuperscript{high}.
^D
<p>A<sub>low</sub> and B<sup>high</sup>.</p>
```

§9: `\listfiles` is parsed and ignored:

```
% pandoc -f latex -t plain
\listfiles[hashes]
Done.
^D
Done.
```
