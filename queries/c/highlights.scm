[
  "default"
  "enum"
  "struct"
  "typedef"
  "union"
  "goto"
] @keyword

"sizeof" @keyword.operator

"return" @keyword.return

[
  "while"
  "for"
  "do"
  "continue"
  "break"
] @repeat

[
 "if"
 "else"
 "case"
 "switch"
] @conditional

[
  "#if"
  "#ifdef"
  "#ifndef"
  "#else"
  "#elif"
  "#endif"
  (preproc_directive)
] @preproc

"#define" @define

"#include" @include

[ ";" ":" "," ] @punctuation.delimiter

"..." @punctuation.special

[ "(" ")" "[" "]" "{" "}"] @punctuation.bracket

[
  "="

  "-"
  "*"
  "/"
  "+"
  "%"

  "~"
  "|"
  "&"
  "^"
  "<<"
  ">>"

  "->"
  "."

  "<"
  "<="
  ">="
  ">"
  "=="
  "!="

  "!"
  "&&"
  "||"

  "-="
  "+="
  "*="
  "/="
  "%="
  "|="
  "&="
  "^="
  ">>="
  "<<="
  "--"
  "++"
] @operator

;; Make sure the comma operator is given a highlight group after the comma
;; punctuator so the operator is highlighted properly.
(comma_expression [ "," ] @operator)

[
 (true)
 (false)
] @boolean

(conditional_expression [ "?" ":" ] @conditional.ternary)

(string_literal) @string
(system_lib_string) @string
;; (escape_sequence) @string.escape

(null) @constant.builtin
(number_literal) @number
(char_literal) @character

[
 (preproc_arg)
 (preproc_defined)
]  @function.macro

(statement_identifier) @label

[
 (type_identifier)
 (sized_type_specifier)
 (type_descriptor)
] @type

(storage_class_specifier) @storageclass

(type_qualifier) @type.qualifier

(type_definition
  declarator: (type_identifier) @type.definition)

(primitive_type) @type.builtin

(enumerator
  name: (identifier) @constant)
(case_statement
  value: (identifier) @constant)

;; Preproc def / undef
(preproc_def
  name: (_) @constant)
 
(call_expression
  function: (identifier) @function.call)
(call_expression
  function: (field_expression
    field: (field_identifier) @function.call))
(function_declarator
  declarator: (identifier) @function)
(preproc_function_def
  name: (identifier) @function.macro)

(field_expression
  (field_identifier) @field)
  
(comment) @comment

;; Parameters
(parameter_declaration
  declarator: (identifier) @parameter)

(parameter_declaration
  declarator: (pointer_declarator
   declarator: (identifier) @parameter))

(preproc_params (identifier) @parameter)

[
  "__attribute__"
  "__cdecl"
  "__clrcall"
  "__stdcall"
  "__fastcall"
  "__thiscall"
  "__vectorcall"
  "_unaligned"
  "__unaligned"
  "__declspec"
  (attribute_declaration)
] @attribute

(ERROR) @error
