; Forked from https://github.com/nvim-treesitter/nvim-treesitter
; Forked from https://github.com/tree-sitter/tree-sitter-rust
; Copyright (c) 2017 Maxim Sokolov
; Licensed under the MIT license.
; (fork fork)

; Identifier conventions

(identifier) @variable
(const_item
  name: (identifier) @constant)

; Other identifiers

(type_identifier) @type
(primitive_type) @type.builtin
(field_identifier) @field
(shorthand_field_initializer
  (identifier) @field)
(mod_item
 name: (identifier) @namespace)

(self) @variable.builtin

(loop_label ["'" (identifier)] @label)


; Function definitions

(function_item (identifier) @function)
(function_signature_item (identifier) @function)

(parameter (identifier) @parameter)
(closure_parameters (_) @parameter)

; Function calls
(call_expression
  function: (identifier) @function.call)
(call_expression
  function: (scoped_identifier
              (identifier) @function.call .))
(call_expression
  function: (field_expression
    field: (field_identifier) @function.call))

(generic_function
  function: (identifier) @function.call)
(generic_function
  function: (scoped_identifier
    name: (identifier) @function.call))
(generic_function
  function: (field_expression
    field: (field_identifier) @function.call))

(enum_variant
  name: (identifier) @constant)

; Assume that uppercase names in paths are types
(scoped_identifier
  path: (identifier) @namespace)
(scoped_identifier
 (scoped_identifier
  name: (identifier) @namespace))
(scoped_type_identifier
  path: (identifier) @namespace)
(scoped_type_identifier
 (scoped_identifier
  name: (identifier) @namespace))

[
  (crate)
  (super)
] @namespace

(scoped_use_list
  path: (identifier) @namespace)
(scoped_use_list
  path: (scoped_identifier
            (identifier) @namespace))
(use_list (scoped_identifier (identifier) @namespace . (_)))

;; Macro definitions
"$" @function.macro
(metavariable) @function.macro
(macro_definition "macro_rules!" @function.macro)

;; Attribute macros
(attribute_item (attribute (identifier) @function.macro))
(attribute (scoped_identifier (identifier) @function.macro .))

;; Derive macros (assume all arguments are types)
; (attribute
;   (identifier) @_name
;   arguments: (attribute (attribute (identifier) @type))
;   (#eq? @_name "derive"))

;; Function-like macros
(macro_invocation
  macro: (identifier) @function.macro)
(macro_invocation
  macro: (scoped_identifier
           (identifier) @function.macro .))



;;; Literals

[
  (line_comment)
  (block_comment)
] @comment

(boolean_literal) @boolean
(integer_literal) @number
(float_literal) @float

[
  (raw_string_literal)
  (string_literal)
] @string
(char_literal) @character


;;; Keywords

[
  "use"
  "mod"
] @include
(use_as_clause "as" @include)

[
  "async"
  "await"
  "default"
  "dyn"
  "enum"
  "extern"
  "impl"
  "let"
  "match"
  "move"
  "pub"
  "struct"
  "trait"
  "type"
  "union"
  "unsafe"
  "where"
] @keyword

[
 "ref"
 (mutable_specifier)
] @type.qualifier

[
 "const"
 "static"
] @storageclass

(lifetime ["'" (identifier)] @storageclass.lifetime)

"fn" @keyword.function
[
  "return"
  "yield"
] @keyword.return

(type_cast_expression "as" @keyword.operator)
(qualified_type "as" @keyword.operator)

(use_list (self) @keyword)
(scoped_use_list (self) @keyword)
(scoped_identifier [(crate) (super) (self)] @keyword)
(visibility_modifier [(crate) (super) (self)] @keyword)

[
  "else"
  "if"
] @conditional

[
  "break"
  "continue"
  "in"
  "loop"
  "while"
] @repeat

"for" @keyword
(for_expression
  "for" @repeat)

;;; Operators & Punctuation

[
  "!"
  "!="
  "%"
  "%="
  "&"
  "&&"
  "&="
  "*"
  "*="
  "+"
  "+="
  "-"
  "-="
  "->"
  ".."
  "..="
  "/"
  "/="
  "<"
  "<<"
  "<<="
  "<="
  "="
  "=="
  "=>"
  ">"
  ">="
  ">>"
  ">>="
  "?"
  "@"
  "^"
  "^="
  "|"
  "|="
  "||"
] @operator

["(" ")" "[" "]" "{" "}"]  @punctuation.bracket
(closure_parameters "|"    @punctuation.bracket)
(type_arguments  ["<" ">"] @punctuation.bracket)
(type_parameters ["<" ">"] @punctuation.bracket)
(bracketed_type ["<" ">"] @punctuation.bracket)
(for_lifetimes ["<" ">"] @punctuation.bracket)

["," "." ":" "::" ";"] @punctuation.delimiter

(attribute_item "#" @punctuation.special)
(inner_attribute_item ["!" "#"] @punctuation.special)
(macro_invocation "!" @function.macro)
(empty_type "!" @type.builtin)
