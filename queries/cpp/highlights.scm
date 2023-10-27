(preproc_def (preproc_arg) @variable)

[
  "default"
  "enum"
  "struct"
  "typedef"
  "union"
  "goto"
  "asm"
  "__asm__"
] @keyword

[
  "sizeof"
  "offsetof"
] @keyword.operator
(alignof_expression . _ @keyword.operator)

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
  "#elifdef"
  "#elifndef"
  (preproc_directive)
] @preproc

"#define" @define

"#include" @include

[ ";" ":" "," "::" ] @punctuation.delimiter

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
(escape_sequence) @string.escape

(null) @constant.builtin
(number_literal) @number
(char_literal) @character

(preproc_defined) @function.macro

(field_designator) @property

(statement_identifier) @label

[
 (type_identifier)
 (type_descriptor)
] @type

(storage_class_specifier) @storageclass

[
  (type_qualifier)
  (gnu_asm_qualifier)
  "__extension__"
] @type.qualifier

(linkage_specification
  "extern" @storageclass)

(type_definition
  declarator: (type_identifier) @type.definition)

(primitive_type) @type.builtin

(sized_type_specifier _ @type.builtin type: _?)

((identifier) @constant
 (#lua-match? @constant "^[A-Z][A-Z0-9_]+$"))
(preproc_def (preproc_arg) @constant
  (#lua-match? @constant "^[A-Z][A-Z0-9_]+$"))
(enumerator
  name: (identifier) @constant)
(case_statement
  value: (identifier) @constant)

((identifier) @constant.builtin
  (#any-of? @constant.builtin
    "stderr" "stdin" "stdout"
    "__FILE__" "__LINE__" "__DATE__" "__TIME__"
    "__STDC__" "__STDC_VERSION__" "__STDC_HOSTED__"
    "__cplusplus" "__OBJC__" "__ASSEMBLER__"
    "__BASE_FILE__" "__FILE_NAME__" "__INCLUDE_LEVEL__"
    "__TIMESTAMP__" "__clang__" "__clang_major__"
    "__clang_minor__" "__clang_patchlevel__"
    "__clang_version__" "__clang_literal_encoding__"
    "__clang_wide_literal_encoding__"
    "__FUNCTION__" "__func__" "__PRETTY_FUNCTION__"
    "__VA_ARGS__" "__VA_OPT__"))
(preproc_def (preproc_arg) @constant.builtin
  (#any-of? @constant.builtin
    "stderr" "stdin" "stdout"
    "__FILE__" "__LINE__" "__DATE__" "__TIME__"
    "__STDC__" "__STDC_VERSION__" "__STDC_HOSTED__"
    "__cplusplus" "__OBJC__" "__ASSEMBLER__"
    "__BASE_FILE__" "__FILE_NAME__" "__INCLUDE_LEVEL__"
    "__TIMESTAMP__" "__clang__" "__clang_major__"
    "__clang_minor__" "__clang_patchlevel__"
    "__clang_version__" "__clang_literal_encoding__"
    "__clang_wide_literal_encoding__"
    "__FUNCTION__" "__func__" "__PRETTY_FUNCTION__"
    "__VA_ARGS__" "__VA_OPT__"))

(attribute_specifier
  (argument_list (identifier) @variable.builtin))
((attribute_specifier
  (argument_list (call_expression
                   function: (identifier) @variable.builtin))))

((call_expression
  function: (identifier) @function.builtin)
  (#lua-match? @function.builtin "^__builtin_"))

;; Preproc def / undef
(preproc_def
  name: (_) @constant)
(preproc_call
  directive: (preproc_directive) @_u
  argument: (_) @constant
  (#eq? @_u "#undef"))

(call_expression
  function: (identifier) @function.call)
(call_expression
  function: (field_expression
    field: (field_identifier) @function.call))
(function_declarator
  declarator: (identifier) @function)
(function_declarator
  declarator: (parenthesized_declarator
                (pointer_declarator
                  declarator: (field_identifier) @function)))
(preproc_function_def
  name: (identifier) @function.macro)

(comment) @comment

((comment) @comment.documentation
  (#lua-match? @comment.documentation "^/[*][*][^*].*[*]/$"))

;; Parameters
(parameter_declaration
  declarator: (identifier) @parameter)

(parameter_declaration
  declarator: (array_declarator) @parameter)

(parameter_declaration
  declarator: (pointer_declarator) @parameter)

(preproc_params (identifier) @parameter)

[
  "__attribute__"
  "__declspec"
  "__based"
  "__cdecl"
  "__clrcall"
  "__stdcall"
  "__fastcall"
  "__thiscall"
  "__vectorcall"
  (ms_pointer_modifier)
  (attribute_declaration)
] @attribute

((identifier) @field
  (#lua-match? @field "^m?_.*$"))

(parameter_declaration
  declarator: (reference_declarator) @parameter)

; function(Foo ...foo)
(variadic_parameter_declaration
  declarator: (variadic_declarator
                (_) @parameter))
; int foo = 0
(optional_parameter_declaration
    declarator: (_) @parameter)

;(field_expression) @parameter ;; How to highlight this?

(field_declaration
  (field_identifier) @field)

(field_initializer
 (field_identifier) @property)

(function_declarator
  declarator: (field_identifier) @method)

(concept_definition
  name: (identifier) @type.definition)

(alias_declaration
  name: (type_identifier) @type.definition)

(auto) @type.builtin

(namespace_identifier) @namespace
((namespace_identifier) @type
  (#lua-match? @type "^[%u]"))

(case_statement
  value: (qualified_identifier (identifier) @constant))

(using_declaration . "using" . "namespace" . [(qualified_identifier) (identifier)] @namespace)

(destructor_name
  (identifier) @method)

; functions
(function_declarator
  (qualified_identifier
    (identifier) @function))
(function_declarator
  (qualified_identifier
    (qualified_identifier
      (identifier) @function)))
(function_declarator
  (qualified_identifier
    (qualified_identifier
      (qualified_identifier
        (identifier) @function))))

(function_declarator
  (template_function
    (identifier) @function))

(operator_name) @function
"operator" @function
"static_assert" @function.builtin

(call_expression
  (qualified_identifier
    (identifier) @function.call))
(call_expression
  (qualified_identifier
    (qualified_identifier
      (identifier) @function.call)))
(call_expression
  (qualified_identifier
    (qualified_identifier
      (qualified_identifier
        (identifier) @function.call))))

(call_expression
  (template_function
    (identifier) @function.call))
(call_expression
  (qualified_identifier
    (template_function
      (identifier) @function.call)))
(call_expression
  (qualified_identifier
    (qualified_identifier
      (template_function
        (identifier) @function.call))))
(call_expression
  (qualified_identifier
    (qualified_identifier
      (qualified_identifier
        (template_function
          (identifier) @function.call)))))

; methods
(function_declarator
  (template_method
    (field_identifier) @method))
(call_expression
  (field_expression
    (field_identifier) @method.call))

; constructors

((function_declarator
  (qualified_identifier
    (identifier) @constructor))
  (#lua-match? @constructor "^%u"))

((call_expression
  function: (identifier) @constructor)
(#lua-match? @constructor "^%u"))
((call_expression
  function: (qualified_identifier
              name: (identifier) @constructor))
(#lua-match? @constructor "^%u"))

((call_expression
  function: (field_expression
              field: (field_identifier) @constructor))
(#lua-match? @constructor "^%u"))

;; constructing a type in an initializer list: Constructor ():  **SuperType (1)**
((field_initializer
  (field_identifier) @constructor
  (argument_list))
 (#lua-match? @constructor "^%u"))


; Constants

(this) @variable.builtin
(null "nullptr" @constant.builtin)

(true) @boolean
(false) @boolean

; Literals

(raw_string_literal)  @string

; Keywords

[
 "try"
 "catch"
 "noexcept"
 "throw"
] @exception


[
 "class"
 "decltype"
 "explicit"
 "friend"
 "namespace"
 "override"
 "template"
 "typename"
 "using"
 "concept"
 "requires"
] @keyword

[
  "co_await"
] @keyword.coroutine

[
 "co_yield"
 "co_return"
] @keyword.coroutine.return

[
 "public"
 "private"
 "protected"
 "virtual"
 "final"
] @type.qualifier

[
 "new"
 "delete"

 "xor"
 "bitand"
 "bitor"
 "compl"
 "not"
 "xor_eq"
 "and_eq"
 "or_eq"
 "not_eq"
 "and"
 "or"
] @keyword.operator

"<=>" @operator

"::" @punctuation.delimiter

(template_argument_list
  ["<" ">"] @punctuation.bracket)

(template_parameter_list
  ["<" ">"] @punctuation.bracket)

(literal_suffix) @operator

(ERROR) @error
