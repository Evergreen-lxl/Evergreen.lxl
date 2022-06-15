;; copied from nvim-treesitter; we're gonna have our own by the time this
;; plugin ever gets off the ground
;; Forked from tree-sitter-go
;; Copyright (c) 2014 Max Brunsfeld (The MIT License)

;;
; Identifiers

(type_identifier) @type
(field_identifier) @property
(identifier) @variable
(package_identifier) @namespace

(parameter_declaration (identifier) @parameter)
(variadic_parameter_declaration (identifier) @parameter)

(const_spec
  name: (identifier) @constant)

; Function calls

(call_expression
  function: (identifier) @function)

(call_expression
  function: (selector_expression
    field: (field_identifier) @method))

; Function definitions

(function_declaration
  name: (identifier) @function)

(method_declaration
  name: (field_identifier) @method)

; Operators

[
  "--"
  "-"
  "-="
  ":="
  "!"
  "!="
  "..."
  "*"
  "*"
  "*="
  "/"
  "/="
  "&"
  "&&"
  "&="
  "%"
  "%="
  "^"
  "^="
  "+"
  "++"
  "+="
  "<-"
  "<"
  "<<"
  "<<="
  "<="
  "="
  "=="
  ">"
  ">="
  ">>"
  ">>="
  "|"
  "|="
  "||"
  "~"
] @operator

; Keywords

[
  "break"
  "chan"
  "const"
  "continue"
  "default"
  "defer"
  "go"
  "goto"
  "interface"
  "map"
  "range"
  "select"
  "struct"
  "type"
  "var"
  "fallthrough"
] @keyword

"func" @keyword.function
"return" @keyword.return

"for" @repeat

[
  "import"
  "package"
] @include

[
  "else"
  "case"
  "switch"
  "if"
 ] @conditional


; Delimiters

"." @punctuation.delimiter
"," @punctuation.delimiter
":" @punctuation.delimiter
";" @punctuation.delimiter

"(" @punctuation.bracket
")" @punctuation.bracket
"{" @punctuation.bracket
"}" @punctuation.bracket
"[" @punctuation.bracket
"]" @punctuation.bracket


; Literals

(interpreted_string_literal) @string
(raw_string_literal) @string
(rune_literal) @string

(int_literal) @number
(float_literal) @float
(imaginary_literal) @number

(true) @boolean
(false) @boolean
[
  (nil)
  (iota)
] @constant.builtin

(comment) @comment
