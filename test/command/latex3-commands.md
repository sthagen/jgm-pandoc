Tests for LaTeX3 (xparse) document command support.

`o` specifier and `\IfNoValueTF`:

```
% pandoc -f latex -t plain
\NewDocumentCommand{\name}{o m}{\IfNoValueTF{#1}{#2}{#1: #2}}
\name{Alice}

\name[Dr]{Bob}
^D
Alice

Dr: Bob
```

`O` specifier with default:

```
% pandoc -f latex -t plain
\NewDocumentCommand\greet{O{Hello} m}{#1, #2!}
\greet{world}

\greet[Hi]{there}
^D
Hello, world!

Hi, there!
```

`s` specifier and `\IfBooleanTF`:

```
% pandoc -f latex -t latex
\NewDocumentCommand\maybeemph{s m}{\IfBooleanTF{#1}{\emph{#2}}{#2}}
\maybeemph{plain} and \maybeemph*{starred}
^D
plain and \emph{starred}
```

`t` specifier:

```
% pandoc -f latex -t plain
\NewDocumentCommand\q{t+ m}{\IfBooleanTF{#1}{plus #2}{noplus #2}}
\q+{a} \q{b}
^D
plus a noplus b
```

`d` specifier with custom delimiters:

```
% pandoc -f latex -t plain
\NewDocumentCommand\point{d()}{\IfNoValueTF{#1}{origin}{(#1)}}
\point, \point(3,4)
^D
origin, (3,4)
```

`r` specifier (required, custom delimiters):

```
% pandoc -f latex -t plain
\NewDocumentCommand\req{r()}{req #1}
\req(ok)
^D
req ok
```

`\DeclareDocumentCommand` redefines silently:

```
% pandoc -f latex -t plain
\DeclareDocumentCommand\x{m}{first: #1}
\DeclareDocumentCommand\x{m}{second: #1}
\x{y}
^D
second: y
```

`\ProvideDocumentCommand` does not redefine:

```
% pandoc -f latex -t plain
\NewDocumentCommand\y{m}{first: #1}
\ProvideDocumentCommand\y{m}{second: #1}
\y{z}
^D
first: z
```

A `-NoValue-` marker that leaks into the document is printed
like in xparse:

```
% pandoc -f latex -t plain
\NewDocumentCommand\val{o}{value: #1}
\val
^D
value: -NoValue-
```

Nested brackets in optional arguments:

```
% pandoc -f latex -t plain
\NewDocumentCommand\opt{o}{got #1}
\opt[a[b]c]
^D
got a[b]c
```

`\IfValueT`:

```
% pandoc -f latex -t plain
\NewDocumentCommand\test{o}{\IfValueT{#1}{seen #1}}
\test[x] \test
^D
seen x
```

Definitions pass through as raw LaTeX when `latex_macros`
is disabled:

```
% pandoc -f markdown-latex_macros -t markdown+raw_tex-raw_attribute
\NewDocumentCommand{\my}{m}{\emph{#1}}
\my{hi}
^D
\NewDocumentCommand{\my}{m}{\emph{#1}}
\my{hi}
```

`\NewDocumentEnvironment`: arguments are available in the
end code, too:

```
% pandoc -f latex -t plain
\NewDocumentEnvironment{titled}{m}{start #1.}{end #1.}
\begin{titled}{T}
middle
\end{titled}
^D
start T. middle end T.
```

Environments with arguments nest properly:

```
% pandoc -f latex -t plain
\NewDocumentEnvironment{wrap}{m}{[#1 }{ #1]}
\begin{wrap}{a}
one
\begin{wrap}{b}
two
\end{wrap}
three
\end{wrap}
^D
[a one [b two b] three a]
```

Environment wrapping another environment, with optional
argument:

```
% pandoc -f latex -t latex
\NewDocumentEnvironment{myquote}{o}
  {\begin{quote}\IfValueT{#1}{\textbf{#1}: }}
  {\end{quote}}
\begin{myquote}[Note]
Hello.
\end{myquote}
^D
\begin{quote}
\textbf{Note}: Hello.
\end{quote}
```

`O` specifier with default in environments:

```
% pandoc -f latex -t plain
\NewDocumentEnvironment{sec}{O{A} m}{(#1/#2 }{ #2)}
\begin{sec}[B]{t}
body
\end{sec}

\begin{sec}{u}
more
\end{sec}
^D
(B/t body t)

(A/u more u)
```

`b` specifier grabs the environment body, trimming
surrounding spaces:

```
% pandoc -f latex -t plain
\NewDocumentEnvironment{titledb}{m b}{Title: #1. Body: #2.}{}
\begin{titledb}{T}
some text
\end{titledb}
^D
Title: T. Body: some text.
```

`\DeclareDocumentEnvironment` redefines silently:

```
% pandoc -f latex -t plain
\DeclareDocumentEnvironment{z}{}{one}{}
\DeclareDocumentEnvironment{z}{}{two}{}
\begin{z}x\end{z}
^D
twox
```

`\ProvideDocumentEnvironment` does not redefine:

```
% pandoc -f latex -t plain
\NewDocumentEnvironment{p}{}{one}{}
\ProvideDocumentEnvironment{p}{}{two}{}
\begin{p}x\end{p}
^D
onex
```

`v` specifier (verbatim), with `\verb`-style delimiters or
braces; special characters are not reinterpreted:

```
% pandoc -f latex -t plain
\NewDocumentCommand\showv{v}{[#1]}
\showv|a_b&\foo|

\showv{xy}
^D
[a_b&\foo]

[xy]
```

`e` specifier (embellishments), matched in any order:

```
% pandoc -f latex -t plain
\NewDocumentCommand\x{e{^_}}{sup=#1, sub=#2.}
\x^{up}_{down}

\x_{down}^{up}

\x_{d}
^D
sup=up, sub=down.

sup=up, sub=down.

sup=-NoValue-, sub=d.
```

`e` specifier with `\IfNoValueTF` and single-token argument:

```
% pandoc -f latex -t plain
\NewDocumentCommand\z{e{^}}{\IfNoValueTF{#1}{none}{got #1}}
\z^2 \z
^D
got 2 none
```

`E` specifier (embellishments with defaults):

```
% pandoc -f latex -t plain
\NewDocumentCommand\y{E{^_}{{U}{D}}}{#1/#2}
\y^{a}

\y
^D
a/D

U/D
```

`\TrimSpaces` argument processor:

```
% pandoc -f latex -t plain
\NewDocumentCommand\trim{>{\TrimSpaces}m}{[#1]}
\trim{  hi  }
^D
[hi]
```

`\ReverseBoolean` argument processor:

```
% pandoc -f latex -t plain
\NewDocumentCommand\rs{>{\ReverseBoolean}s}{\IfBooleanTF{#1}{T}{F}}
\rs* \rs
^D
F T
```

`\SplitArgument` processor: splits into braced groups, trims
spaces, pads with `-NoValue-`:

```
% pandoc -f latex -t plain
\NewDocumentCommand\three{mmm}{1=#1, 2=#2, 3=#3.}
\NewDocumentCommand\splt{>{\SplitArgument{2}{;}}m}{\three#1}
\splt{a; b ;c}

\splt{a;b}
^D
1=a, 2=b, 3=c.

1=a, 2=b, 3=-NoValue-.
```

`\SplitList` processor:

```
% pandoc -f latex -t plain
\NewDocumentCommand\lst{>{\SplitList{,}}m}{items: #1}
\lst{x, y ,z}
^D
items: xyz
```

Multiple processors are applied starting from the one nearest
the argument specifier:

```
% pandoc -f latex -t plain
\NewDocumentCommand\two{mm}{(#1)(#2)}
\NewDocumentCommand\c{>{\SplitArgument{1}{;}}>{\TrimSpaces}m}{\two#1}
\c{ a;b }
^D
(a)(b)
```

Unknown processors are skipped, keeping the argument:

```
% pandoc -f latex -t plain
\NewDocumentCommand\u{>{\SomeUnknownProc}m}{[#1]}
\u{ok}
^D
[ok]
```

`\NewCommandCopy` snapshots the definition (like `\let`):

```
% pandoc -f latex -t plain
\NewDocumentCommand\old{m}{orig: #1}
\NewCommandCopy\new\old
\RenewDocumentCommand\old{m}{changed: #1}
\new{a} \old{b}
^D
orig: a changed: b
```

`\NewEnvironmentCopy`, copying a built-in environment:

```
% pandoc -f latex -t latex
\NewEnvironmentCopy{myquote}{quote}
\begin{myquote}
Hello.
\end{myquote}
^D
\begin{quote}
Hello.
\end{quote}
```

`\MakeTitlecase` uppercases the first character:

```
% pandoc -f latex -t plain
\MakeTitlecase{hello world} \MakeTitlecase{\emph{foo bar}}
^D
Hello world Foo bar
```

Code between `\ExplSyntaxOn` and `\ExplSyntaxOff` is
tokenized with `:` and `_` as letters, so it can be skipped
cleanly:

```
% pandoc -f latex -t plain
\ExplSyntaxOn
\tl_new:N \l_my_tl
\tl_set:Nn \l_my_tl {stuff}
\ExplSyntaxOff
Text after.
^D
Text after.
```

`\ShowCommand` and the key–value commands are parsed and
ignored:

```
% pandoc -f latex -t plain
\NewDocumentCommand\foo{m}{x#1}
\ShowCommand\foo
\DeclareKeys[fam]{key .store = \myval}
\SetKeys[fam]{key=5}
\ProcessKeyOptions[fam]
Done.
^D
Done.
```

`\inteval`: `+ - * /` with division rounding to nearest (ties
away from zero, as in eTeX):

```
% pandoc -f latex -t plain
\inteval{2+3*4}, \inteval{7/2}, \inteval{-7/2}, \inteval{(1+2)*3}
^D
14, 4, -4, 9
```

Macros in the evaluator argument are expanded:

```
% pandoc -f latex -t plain
\NewDocumentCommand\n{}{4}
\inteval{\n + 1}
^D
5
```

`\fpeval`: floating point expressions; results are rounded to
16 significant digits as in l3fp:

```
% pandoc -f latex -t plain
\fpeval{2^10/8}, \fpeval{0.1 + 0.2}, \fpeval{2**3}, \fpeval{1e3*2}, \fpeval{1/3}
^D
128, 0.3, 8, 2000, 0.3333333333333333
```

Expressions that cannot be evaluated are passed through as
text:

```
% pandoc -f latex -t plain
\fpeval{foo(1)}, \fpeval{1/0}, \inteval{1/0}
^D
foo(1), 1/0, 1/0
```

`\dimeval` and `\skipeval` substitute their (unevaluated)
expression:

```
% pandoc -f latex -t plain
\dimeval{2pt+3pt}, \skipeval{1em plus 2pt}
^D
2pt+3pt, 1em plus 2pt
```
