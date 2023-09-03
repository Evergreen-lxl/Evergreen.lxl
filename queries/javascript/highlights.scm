; INHERITS: ECMA START
; Types

; Javascript

; Variables
;-----------
(identifier) @variable

; Properties
;-----------

(property_identifier) @property
(shorthand_property_identifier) @property
(private_property_identifier) @property

(variable_declarator
  name: (object_pattern
    (shorthand_property_identifier_pattern))) @variable

; Special identifiers
;--------------------

((identifier) @type
 (#lua-match? @type "^[A-Z]"))

((identifier) @constant
 (#lua-match? @constant "^_*[A-Z][A-Z%d_]*$"))

((shorthand_property_identifier) @constant
 (#lua-match? @constant "^_*[A-Z][A-Z%d_]*$"))

((identifier) @variable.builtin
 (#any-of? @variable.builtin
           "arguments"
           "module"
           "console"
           "window"
           "document"))

((identifier) @type.builtin
 (#any-of? @type.builtin
           "Object"
           "Function"
           "Boolean"
           "Symbol"
           "Number"
           "Math"
           "Date"
           "String"
           "RegExp"
           "Map"
           "Set"
           "WeakMap"
           "WeakSet"
           "Promise"
           "Array"
           "Int8Array"
           "Uint8Array"
           "Uint8ClampedArray"
           "Int16Array"
           "Uint16Array"
           "Int32Array"
           "Uint32Array"
           "Float32Array"
           "Float64Array"
           "ArrayBuffer"
           "DataView"
           "Error"
           "EvalError"
           "InternalError"
           "RangeError"
           "ReferenceError"
           "SyntaxError"
           "TypeError"
           "URIError"))

((identifier) @namespace.builtin
 (#eq? @namespace.builtin "Intl"))

((identifier) @function.builtin
 (#any-of? @function.builtin
           "eval"
           "isFinite"
           "isNaN"
           "parseFloat"
           "parseInt"
           "decodeURI"
           "decodeURIComponent"
           "encodeURI"
           "encodeURIComponent"
           "require"))

; Function and method definitions
;--------------------------------

(function
  name: (identifier) @function)
(function_declaration
  name: (identifier) @function)
(generator_function
  name: (identifier) @function)
(generator_function_declaration
  name: (identifier) @function)
(method_definition
  name: [(property_identifier) (private_property_identifier)] @method)
(method_definition
  name: (property_identifier) @constructor
  (#eq? @constructor "constructor"))

(pair
  key: (property_identifier) @method
  value: (function))
(pair
  key: (property_identifier) @method
  value: (arrow_function))

(assignment_expression
  left: (member_expression
    property: (property_identifier) @method)
  right: (arrow_function))
(assignment_expression
  left: (member_expression
    property: (property_identifier) @method)
  right: (function))

(variable_declarator
  name: (identifier) @function
  value: (arrow_function))
(variable_declarator
  name: (identifier) @function
  value: (function))

(assignment_expression
  left: (identifier) @function
  right: (arrow_function))
(assignment_expression
  left: (identifier) @function
  right: (function))

; Function and method calls
;--------------------------

(call_expression
  function: (identifier) @function.call)

(call_expression
  function: (member_expression
    property: [(property_identifier) (private_property_identifier)] @method.call))

; Constructor
;------------

(new_expression
  constructor: (identifier) @constructor)

; Variables
;----------
(namespace_import
  (identifier) @namespace)

; Decorators
;----------
(decorator "@" @attribute (identifier) @attribute)
(decorator "@" @attribute (call_expression (identifier) @attribute))

; Literals
;---------

[
  (this)
  (super)
] @variable.builtin

((identifier) @variable.builtin
 (#eq? @variable.builtin "self"))

[
  (true)
  (false)
] @boolean

[
  (null)
  (undefined)
] @constant.builtin

(comment) @comment

((comment) @comment.documentation
  (#lua-match? @comment.documentation "^/[*][*][^*].*[*]/$"))

(hash_bang_line) @preproc

((string_fragment) @preproc
 (#eq? @preproc "use strict"))

(string) @string
(template_string) @string
(escape_sequence) @string.escape
(regex_pattern) @string.regex
(regex_flags) @character.special
(regex "/" @punctuation.bracket) ; Regex delimiters

(number) @number
((identifier) @number
  (#any-of? @number "NaN" "Infinity"))

; Punctuation
;------------

";" @punctuation.delimiter
"." @punctuation.delimiter
"," @punctuation.delimiter

(pair ":" @punctuation.delimiter)
(pair_pattern ":" @punctuation.delimiter)
(switch_case ":" @punctuation.delimiter)
(switch_default ":" @punctuation.delimiter)

[
  "--"
  "-"
  "-="
  "&&"
  "+"
  "++"
  "+="
  "&="
  "/="
  "**="
  "<<="
  "<"
  "<="
  "<<"
  "="
  "=="
  "==="
  "!="
  "!=="
  "=>"
  ">"
  ">="
  ">>"
  "||"
  "%"
  "%="
  "*"
  "**"
  ">>>"
  "&"
  "|"
  "^"
  "??"
  "*="
  ">>="
  ">>>="
  "^="
  "|="
  "&&="
  "||="
  "??="
  "..."
] @operator

(binary_expression "/" @operator)
(ternary_expression ["?" ":"] @conditional.ternary)
(unary_expression ["!" "~" "-" "+"] @operator)
(unary_expression ["delete" "void"] @keyword.operator)

[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

((template_substitution ["${" "}"] @punctuation.special) @none)

; Keywords
;----------

[
  "if"
  "else"
  "switch"
  "case"
] @conditional

[
  "import"
  "from"
] @include

(export_specifier "as" @include)
(import_specifier "as" @include)
(namespace_export "as" @include)
(namespace_import "as" @include)

[
  "for"
  "of"
  "do"
  "while"
  "continue"
] @repeat

[
  "break"
  "class"
  "const"
  "debugger"
  "export"
  "extends"
  "get"
  "let"
  "set"
  "static"
  "target"
  "var"
  "with"
] @keyword

[
  "async"
  "await"
] @keyword.coroutine

[
  "return"
  "yield"
] @keyword.return

[
  "function"
] @keyword.function

[
  "new"
  "delete"
  "in"
  "instanceof"
  "typeof"
] @keyword.operator

[
  "throw"
  "try"
  "catch"
  "finally"
] @exception

(export_statement
  "default" @keyword)
(switch_default
  "default" @conditional)

; INHERITS END
; JSX START
(jsx_element
  open_tag: (jsx_opening_element ["<" ">"] @tag.delimiter))
(jsx_element
  close_tag: (jsx_closing_element ["</" ">"] @tag.delimiter))
(jsx_self_closing_element ["<" "/>"] @tag.delimiter)
(jsx_attribute (property_identifier) @tag.attribute)

(jsx_opening_element
  name: (identifier) @tag)

(jsx_closing_element
  name: (identifier) @tag)

(jsx_self_closing_element
  name: (identifier) @tag)

(jsx_opening_element ((identifier) @constructor
 (#lua-match? @constructor "^[A-Z]")))

; Handle the dot operator effectively - <My.Component>
(jsx_opening_element ((member_expression (identifier) @tag (property_identifier) @constructor)))

(jsx_closing_element ((identifier) @constructor
 (#lua-match? @constructor "^[A-Z]")))

; Handle the dot operator effectively - </My.Component>
(jsx_closing_element ((member_expression (identifier) @tag (property_identifier) @constructor)))

(jsx_self_closing_element ((identifier) @constructor
 (#lua-match? @constructor "^[A-Z]")))

; Handle the dot operator effectively - <My.Component />
(jsx_self_closing_element ((member_expression (identifier) @tag (property_identifier) @constructor)))

(jsx_text) @none
; JSX END
; JS START
;;; Parameters
(formal_parameters (identifier) @parameter)

(formal_parameters
  (rest_pattern
    (identifier) @parameter))

;; ({ a }) => null
(formal_parameters
  (object_pattern
    (shorthand_property_identifier_pattern) @parameter))

;; ({ a = b }) => null
(formal_parameters
  (object_pattern
    (object_assignment_pattern
      (shorthand_property_identifier_pattern) @parameter)))

;; ({ a: b }) => null
(formal_parameters
  (object_pattern
    (pair_pattern
      value: (identifier) @parameter)))

;; ([ a ]) => null
(formal_parameters
  (array_pattern
    (identifier) @parameter))

;; ({ a } = { a }) => null
(formal_parameters
  (assignment_pattern
    (object_pattern
      (shorthand_property_identifier_pattern) @parameter)))

;; ({ a = b } = { a }) => null
(formal_parameters
  (assignment_pattern
    (object_pattern
      (object_assignment_pattern
        (shorthand_property_identifier_pattern) @parameter))))

;; a => null
(arrow_function
  parameter: (identifier) @parameter)

;; optional parameters
(formal_parameters
  (assignment_pattern
    left: (identifier) @parameter))

;; punctuation
(optional_chain) @punctuation.delimiter
