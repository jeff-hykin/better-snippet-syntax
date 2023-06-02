# frozen_string_literal: true
require 'ruby_grammar_builder'
require 'walk_up'
require_relative walk_up_until("paths.rb")
require_relative './tokens.rb'

# 
# 
# create grammar!
# 
# 
grammar = Grammar.fromTmLanguage("./main/modified.tmLanguage.json")
grammar.name = "jsonc"
grammar.scope_name = "source.json.comments"

# 
#
# setup grammar
#
# 
    grammar[:$initial_context] = [
        :value, # value is defined in the modified.tmLanguage.json
    ]

# 
# generic helpers
# 
    # reference of what already exists:
        # @space
        # @spaces
        # @digit
        # @digits
        # @standard_character
        # @word
        # @word_boundary
        # @white_space_start_boundary
        # @white_space_end_boundary
        # @start_of_document
        # @end_of_document
        # @start_of_line
        # @end_of_line
    part_of_a_variable = /[_a-zA-Z][_a-zA-Z0-9]*/ # according to VS Code docs
    # this is really useful for keywords. eg: variableBounds[/new/] wont match "newThing" or "thingnew"
    variableBounds = ->(regex_pattern) do
        lookBehindToAvoid(@standard_character).then(regex_pattern).lookAheadToAvoid(@standard_character)
    end
    variable = variableBounds[part_of_a_variable]
    
# 
# patterns
# 
    # overwrite the stringcontent
    normal_escape_tag            = "constant.character.escape"
    double_escaper_tag           = "punctuation.section.insertion.escape.escaper comment.block punctuation.definition.comment.insertion.escape"
    double_escapee_tag           = "punctuation.section.insertion.escape.escapee string.regexp.insertion.escape string.quoted.double"
    normal_string_character_tag  = "string.quoted.double"
    insertion_tag                = "keyword.operator.insertion"
    numeric_variable_tag         = "custom.variable.other.normal.numeric"
    named_variable_tag           = "custom.variable.other.normal.named"
    
    simple_insertion_tag  = "meta.insertion.simple"
    bracket_insertion_tag = "meta.insertion.brackets"
    choice_meta_tag       = "meta.insertion.choice"
    
    # 
    # 
    # helpers for BNF form
    # 
    # 
        # 
        # escapes
        # 
            grammar[:basic_escape] = Pattern.new(
                tag_as: normal_escape_tag,
                match: Pattern.new(/\\/).then(
                    Pattern.new(/["\\\/bfnrt]/).or(/u[0-9a-fA-F]{4}/)
                ),
            )
            grammar[:invalid_escape] = Pattern.new(
                tag_as: "#{normal_escape_tag} invalid.illegal.unrecognized-string-escape",
                match: Pattern.new(/\\./),
            )
            grammar[:quad_backslash_match] = Pattern.new(
                Pattern.new(
                    tag_as: double_escaper_tag,
                    match: /\\\\/,
                ).then(
                    tag_as: normal_escape_tag,
                    match: /\\\\/,
                ),
            )
            grammar[:null_quad_backslash] = Pattern.new(
                match: Pattern.new(
                    # FIXME: check what \\\" does
                    match: lookAheadToAvoid(/\\/).oneOf([
                        Pattern.new(/\\\\/).zeroOrMoreOf(match: /\\\\\\\\/, no_backtrack: true).then(
                            Pattern.new(/[^\{\$"\\]/).or(lookAheadFor('"'))
                        ),
                        oneOrMoreOf(match: /\\\\\\\\/, no_backtrack: true).then(
                            Pattern.new(/[^\{\$"\\]/).or(lookAheadFor('"'))
                        ),
                    ]),
                    includes: [
                        # quad match
                        :quad_backslash_match,
                        :dollar_sign_escape,
                        :bracket_escape,
                        :basic_escape,
                        :invalid_escape,
                        :normal_characters,
                    ],
                )
            )
            grammar[:dollar_sign_escape] = Pattern.new(
                match: lookBehindToAvoid(/\\/).then(
                    Pattern.new(
                        zeroOrMoreOf(match: /\\\\\\\\/, no_backtrack: true).then(
                            Pattern.new(/\\\\/).then("$")
                        )
                    ).or("\\$")
                ),
                includes: [
                    :quad_backslash_match,
                    Pattern.new(
                        tag_as: double_escapee_tag,
                        match: Pattern.new(
                            tag_as: double_escaper_tag,
                            match: /\\\\/,
                        ).then("$")
                    ),
                    :invalid_escape,
                ]
            )
            grammar[:bracket_escape] = Pattern.new(
                match: lookBehindToAvoid(/\\/).zeroOrMoreOf(match: /\\\\\\\\/, no_backtrack: true).then(
                    Pattern.new(/\\\\/).then("}")
                ),
                includes: [
                    :quad_backslash_match,
                    Pattern.new(
                        tag_as: double_escapee_tag,
                        match: Pattern.new(
                            tag_as: double_escaper_tag,
                            match: /\\\\/,
                        ).then("}")
                    ),
                ]
            )
            grammar[:normal_characters] = Pattern.new(
                tag_as: normal_string_character_tag,
                match: /[^\\\n\}"]/, # normal characters
            )
            grammar[:simple_escape_context] = oneOf([
                grammar[:null_quad_backslash],
                grammar[:dollar_sign_escape],
                grammar[:bracket_escape],
                grammar[:quad_backslash_match],
                grammar[:basic_escape],
                grammar[:invalid_escape],
                grammar[:normal_characters],
            ])
            grammar[:choice_option_escape]  = Pattern.new(
                # escapes | and ,
                Pattern.new(
                    match: /\/\//,
                    tag_as: double_escaper_tag,
                ).then(
                    /\,|\|/
                )
            )
            grammar[:regex_backslash_escape] = oneOf([
                # single escape
                Pattern.new(
                    # \\/
                    Pattern.new(
                        match: /\\/,
                        tag_as: double_escaper_tag,
                    ).then(
                        match: /\\\//,
                        tag_as: double_escapee_tag,
                    )
                ),
                # double escape
                Pattern.new(
                    # \\\\/
                    Pattern.new(
                        match: /\\\\\\/,
                        tag_as: double_escaper_tag,
                    ).then(
                        match: /\\\//,
                        tag_as: double_escapee_tag,
                    )
                )
            ])
        # 
        # bracket helpers
        # 
            grammar[:bracket_insertion_starter] = Pattern.new(
                Pattern.new(
                    tag_as: "punctuation.section.insertion.dollar.brackets #{insertion_tag} custom.punctuation.section.insertion.dollar.brackets",
                    match: "$",
                ).then(
                    tag_as: "punctuation.section.insertion.bracket #{insertion_tag} custom.punctuation.section.insertion.bracket",
                    match: "{",
                )
            )
            grammar[:bracket_insertion_ender] = Pattern.new(
                Pattern.new(
                    tag_as: "punctuation.section.insertion.bracket #{insertion_tag} custom.punctuation.section.insertion.bracket",
                    match: "}",
                )
            )
            grammar[:colon_separator] = Pattern.new(
                tag_as: "punctuation.section.insertion punctuation.separator.colon #{insertion_tag} custom.punctuation.separator.colon",
                match: ":",
            )
        # 
        # choice
        # 
            grammar[:choice_option] = Pattern.new(
                tag_as: "#{choice_meta_tag} constant.other.option", # NOTE: shouldn't need this choice_meta_tag (redundant) but textmate engine seems to have a problem and this is a workaround
                reference: "choice_text",
                match: oneOrMoreOf(
                    oneOf([
                        grammar[:quad_backslash_match],
                        grammar[:choice_option_escape],
                        grammar[:null_quad_backslash],
                        grammar[:dollar_sign_escape],
                        grammar[:bracket_escape],
                        grammar[:basic_escape],
                        # basic text
                        /[^,}\|]/,
                    ])
                ),
            )
        # see: https://code.visualstudio.com/docs/editor/userdefinedsnippets#_variables
        grammar[:special_variables] = Pattern.new(
            Pattern.new(
                tag_as: "#{simple_insertion_tag} punctuation.section.insertion.dollar.simple #{insertion_tag} variable.language.this",
                match: "$",
            ).then(
                tag_as: "#{simple_insertion_tag} #{insertion_tag} variable.language.this",
                match: variableBounds[/TM_SELECTED_TEXT|TM_CURRENT_LINE|TM_CURRENT_WORD|TM_LINE_INDEX|TM_LINE_NUMBER|TM_FILENAME|TM_FILENAME_BASE|TM_DIRECTORY|TM_FILEPATH|RELATIVE_FILEPATH|CLIPBOARD|WORKSPACE_NAME|WORKSPACE_FOLDER|CURSOR_INDEX|CURSOR_NUMBER|CURRENT_YEAR|CURRENT_YEAR_SHORT|CURRENT_MONTH|CURRENT_MONTH_NAME|CURRENT_MONTH_NAME_SHORT|CURRENT_DATE|CURRENT_DAY_NAME|CURRENT_DAY_NAME_SHORT|CURRENT_HOUR|CURRENT_MINUTE|CURRENT_SECOND|CURRENT_SECONDS_UNIX|CURRENT_TIMEZONE_OFFSET|RANDOM|RANDOM_HEX|UUID|BLOCK_COMMENT_START|BLOCK_COMMENT_END|LINE_COMMENT/],
            )
        )
    # 
    # 
    # BNF form
    # 
    # 
        # this is a modified (corrected) version of the VS Code BNF definition of their snippets
        # source: https://code.visualstudio.com/docs/editor/userdefinedsnippets#_placeholdertransform
        # the patterns below very very very closely follow this grammar definition:
        # modified BNF definition:
            # int         ::= /[0-9]+/
            # var         ::= /[_a-zA-Z][_a-zA-Z0-9]*/
            # text        ::= /.?.+?/
            #                 # NOTE: the VS Code docs says ".*" however this is 
            #                 # not accurate based on the implementation
            #                 # the implementation is definitely non-greedy, with a caveat;
            #                 # this modified version will greedily-match 1 character
            #                 # and then non-greedily match more characters
            # if          ::= text # just an alias for text
            # else        ::= text # just an alias for text
            # regex       ::= JavaScript Regular Expression value (ctor-string) # VS Code doesnt elaborate
            # options     ::= /[igmyu]{0,5}/ # VS Code docs doesnt define this, but this is what it is
            # choice      ::= '${' int '|' text (',' text)* '|}'
            #                 # NOTE1: this is what the VS Code docs says
            #                 # however the text needs additional escape patterns
            #                 # specifically escaping comma and vertical bar (|)
            #                 # NOTE2: as usual the text can also recursively contain other injections
            #                 # although this seems like a failed implementation as sometimes VS code
            #                 # gets confused by them in undefined-behavior like ways
            # format      ::= '$' int
            #                 | '${' int '}'
            #                 | '${' int ':' '/upcase' | '/downcase' | '/capitalize' | '/camelcase' | '/pascalcase' '}'
            #                 | '${' int ':+' if '}'
            #                 | '${' int ':?' if ':' else '}'
            #                 | '${' int ':-' else '}'
            #                 | '${' int ':' else '}'
            #                 # NOTE: this is slightly wrong as the "if" and "else" are supposedly just text
            #                 # however in the implementation they can actually recursively contain format
            #                 # (so in practice it is closer to "ANY")
            #                 # additionally the text handles escapes differently 
            # transform   ::= '/' regex '/' (format | text)* '/' options
            #                 # NOTE: in VS Code's docs its "(format | text)+" not "(format | text)*"
            #                 # however, the + is wrong based on their examples and the implementation
            # tabstop     ::=   '$' int
            #                 | '${' int '}'
            #                 | '${' int  transform '}'
            # # the following are the only ones that can't be defined in a heirarchy (e.g. they're recursive)
            # placeholder ::= '${' int ':' any '}'
            # variable    ::= '$' var
            #                 | '${' var '}'
            #                 | '${' var ':' any '}'
            #                 | '${' var transform '}'
            # any         ::= tabstop
            #                 | placeholder
            #                 | choice
            #                 | variable
            #                 | text
        
        # int         ::= /[0-9]+/
        grammar[:bnf_int]    = Pattern.new(
            tag_as: "variable.other.normal #{numeric_variable_tag}",
            match: /[0-9]+/,
        )
        grammar[:bnf_int_simple]    = Pattern.new(
            tag_as: "variable.other.normal #{insertion_tag} #{numeric_variable_tag}",
            match: /[0-9]+/,
        )
        # var         ::= /[_a-zA-Z][_a-zA-Z0-9]*/
        grammar[:bnf_var]    = Pattern.new(
            tag_as: "variable.other.normal #{named_variable_tag}",
            match: variableBounds[/[_a-zA-Z][_a-zA-Z0-9]*/],
        )
        grammar[:bnf_var_simple]    = Pattern.new(
            tag_as: "variable.other.normal #{insertion_tag} #{named_variable_tag}",
            match: variableBounds[/[_a-zA-Z][_a-zA-Z0-9]*/],
        )
        # text        ::= /.?.+?/
        grammar[:bnf_text]   = Pattern.new(
            match: maybe(grammar[:simple_escape_context]).zeroOrMoreOf(
                as_few_as_possible?: true,
                match: grammar[:simple_escape_context],
            ),
            includes: [
                :special_variables,
                :simple_escape_context,
            ]
        )
        # choice ::= '${' int '|' text (',' text)* '|}'
        grammar[:bnf_choice] = Pattern.new(
            tag_as: "#{bracket_insertion_tag} #{choice_meta_tag}",
            match: Pattern.new(
                grammar[:bracket_insertion_starter].then(
                    grammar[:bnf_int]
                ).then(
                    tag_as: "punctuation.separator.choice #{insertion_tag} custom.punctuation.separator.choice",
                    match: "|",
                ).then(
                    # TODO: this could be cleaned up by making a :bnf_text_choice pattern that included choice-exclusive escapes
                    # NOTE: functionally VS Code allows choice_option to recursively include more insertions
                    #       however that functionality goes against its own extended Backus-Naur form specification
                    #       this highligher doesn't support the functionality
                    match: grammar[:choice_option].then(
                        zeroOrMoreOf(
                            as_few_as_possible?: true,
                            match: Pattern.new(
                                Pattern.new(
                                    match: ","
                                ).then(
                                    recursivelyMatch("choice_text")
                                )
                            ),
                        ),
                    ),
                    includes: [
                         Pattern.new(
                            tag_as: "#{choice_meta_tag} punctuation.separator.comma", # NOTE: shouldn't need this choice_meta_tag (redundant) but textmate engine seems to have a problem and this is a workaround
                            match: ","
                        ),
                        :choice_option,
                    ]
                ).then(
                    tag_as: "punctuation.separator.choice #{insertion_tag} custom.punctuation.separator.choice",
                    match: "|",
                ).then(
                    grammar[:bracket_insertion_ender]
                )
            )
        )
        # format      ::= '$' int
        #         | '${' int '}'
        #         | '${' int ':' '/upcase' | '/downcase' | '/capitalize' | '/camelcase' | '/pascalcase' '}'
        #         | '${' int ':+' text '}'
        #         | '${' int ':?' text ':' text '}'
        #         | '${' int ':-' text '}'
        #         | '${' int ':' text '}'
        grammar[:bnf_format] = Pattern.new(
            # 
            # case 1: '$' int
            # 
            grammar[:special_variables].or(
                tag_as: "#{simple_insertion_tag}.numeric meta.insertion.format.simple",
                should_fully_match: [ "$1", "$2", ],
                match: Pattern.new(
                    Pattern.new(
                        match:"$",
                        tag_as: "punctuation.section.insertion.dollar.simple #{insertion_tag} custom.punctuation.section.insertion.dollar.simple",
                    ).then(
                        grammar[:bnf_int_simple]
                    )
                )
            # 
            # case 2: '${' int ':' '/upcase' | '/downcase' | '/capitalize' | '/camelcase' | '/pascalcase' '}'
            # 
            ).or(
                tag_as: "#{bracket_insertion_tag} meta.insertion.format.transform",
                match: Pattern.new(
                    grammar[:bracket_insertion_starter].then(
                        grammar[:bnf_int]
                    ).then(
                        grammar[:colon_separator]
                    ).then(
                        Pattern.new(
                            tag_as: "punctuation.section.regexp support.type.built-in variable.language.special.transform",
                            match: /\//,
                        ).then(
                            tag_as: "support.type.built-in variable.language.special.transform",
                            match: /upcase|downcase|capitalize|camelcase|pascalcase/,
                        )
                    ).then(
                        grammar[:bracket_insertion_ender]
                    )
                ),
            # 
            # case 3: '${' int ':+' text '}'
            # 
            ).or(
                tag_as: "#{bracket_insertion_tag} meta.insertion.format.plus",
                match: Pattern.new(
                    grammar[:bracket_insertion_starter].then(
                        grammar[:bnf_int]
                    ).then(
                        grammar[:colon_separator]
                    ).then(
                        tag_as: "punctuation.separator.plus",
                        match: "+",
                    ).then(
                        grammar[:bnf_text]
                    ).then(
                        grammar[:bracket_insertion_ender]
                    )
                ),
            # 
            # case 4: '${' int ':?' text ':' text '}'
            # 
            ).or(
                tag_as: "#{bracket_insertion_tag} meta.insertion.format.conditional",
                match: Pattern.new(
                    grammar[:bracket_insertion_starter].then(
                        grammar[:bnf_int]
                    ).then(
                        grammar[:colon_separator]
                    ).then(
                        tag_as: "punctuation.separator.conditional keyword.operator.ternary",
                        match: "?",
                    ).then(
                        # TODO: check if there is a colon-escape, might need a seperate :bnf_text_colon_escape pattern
                        grammar[:bnf_text]
                    ).then(
                        tag_as: "keyword.operator.ternary",
                        match: /:/,
                    ).then(
                        # TODO: check if there is a colon-escape, might need a seperate :bnf_text_colon_escape pattern
                        grammar[:bnf_text]
                    ).then(
                        grammar[:bracket_insertion_ender]
                    )
                ),
            # 
            # case 5: '${' int ':-' text '}'
            # 
            ).or(
                tag_as: "#{bracket_insertion_tag} meta.insertion.format.remove",
                match: Pattern.new(
                    grammar[:bracket_insertion_starter].then(
                        grammar[:bnf_int]
                    ).then(
                        grammar[:colon_separator]
                    ).then(
                        tag_as: "punctuation.separator.dash",
                        match: "-",
                    ).then(
                        grammar[:bnf_text]
                    ).then(
                        grammar[:bracket_insertion_ender]
                    )
                ),
            # 
            # case 6: '${' int ':' text '}'
            # 
            ).or(
                tag_as: "#{bracket_insertion_tag} meta.insertion.format.default",
                match: Pattern.new(
                    grammar[:bracket_insertion_starter].then(
                        grammar[:bnf_int]
                    ).then(
                        grammar[:colon_separator]
                    ).then(
                        grammar[:bnf_text]
                    ).then(
                        grammar[:bracket_insertion_ender]
                    )
                ),
            )
        )
        # transform   ::= '/' REGEX '/' (format | text )+ '/' REGEX_OPTIONS
        grammar[:bnf_transform] = Pattern.new(
            # 
            # finding: /THIS/WHOLE THING/
            # 
            tag_as: "meta.insertion.transform string.regexp",
            # TODO: concerns: escaping the \} from ${} while also escaping it for JSON and for regex
            match: Pattern.new(
                Pattern.new(
                    match: "/",
                    tag_as: "punctuation.section.regexp",
                ).then(
                    # 
                    # finding: /BEGINING_PART//
                    # 
                    match: oneOrMoreOf(
                        # regex escape or anything thats not a slash
                        match: grammar[:regex_backslash_escape].or(/[^\/\n]/),
                        # dont_back_track?: false,
                    ),
                    includes: [
                        "source.syntax.regexp", # FIXME: this include isnt working
                        grammar[:regex_backslash_escape],
                        # TODO: this is where to add regex highlighting similar to https://github.com/RedCMD/TmLanguage-Syntax-Highlighter
                        #       maybe could just embed his
                        # FIXME: the escapes for regex are probably slightly different 
                        #        for example escaping a $ compared to escaping the $ for ${1:stuff}
                        #        on top of also escaping a [ or {
                        #        currently the code does not account for any of that
                        :simple_escape_context,
                    ],
                ).then(
                    match: "/",
                    tag_as: "punctuation.section.regexp",
                ).then(
                    # 
                    # finding: //ENDING_PART/
                    # 
                    match: zeroOrMoreOf(
                        # regex escape or anything thats not a slash
                        match: grammar[:bnf_format].or(
                            grammar[:regex_backslash_escape].or(
                                Pattern.new(
                                    tag_as: "text.$match",
                                    match: zeroOrMoreOf(
                                        match: grammar[:simple_escape_context].or(/[^\n\r]/),
                                    ),
                                    includes: [
                                        :special_variables,
                                        :simple_escape_context,
                                    ]
                                )
                            ),
                        ),
                    ),
                    includes: [
                        Pattern.new(
                            tag_as: "variable.language.capture",
                            match: /\$\d+/,
                        ),
                        :bnf_format,
                        :regex_backslash_escape,
                        :bnf_text,
                        # TODO: should also include other escape sequences
                    ]
                ).then(
                    match: "/",
                    tag_as: "punctuation.section.regexp",
                ).then(
                    tag_as: "keyword.other.flag",
                    match: /[igmyu]{0,5}/,
                )
            )
        )
        # tabstop     ::= '$' int
        #     | '${' int '}'
        #     | '${' int  transform '}'
        grammar[:bnf_tabstop] = Pattern.new(
            # 
            # case 1: '$' int
            # 
            Pattern.new(
                tag_as: "#{simple_insertion_tag}.numeric meta.insertion.tabstop.simple",
                should_fully_match: [ "$1", "$2", ],
                match: Pattern.new(
                    Pattern.new(
                        match:"$",
                        tag_as: "punctuation.section.insertion.dollar.simple #{insertion_tag} custom.punctuation.section.insertion.dollar.simple",
                    ).then(
                        grammar[:bnf_int_simple]
                    )
                )
            # 
            # case 2: '${' int '}'
            # 
            ).or(
                tag_as: "#{bracket_insertion_tag} meta.insertion.tabstop.bracket",
                match: Pattern.new(
                    grammar[:bracket_insertion_starter].then(
                        grammar[:bnf_int_simple]
                    ).then(
                        grammar[:bracket_insertion_ender]
                    )
                ),
            # 
            # case 3: '${' int  transform '}'
            # 
            ).or(
                tag_as: "#{bracket_insertion_tag} meta.insertion.tabstop.transform",
                match: Pattern.new(
                    grammar[:bracket_insertion_starter].then(
                        grammar[:bnf_int]
                    ).then(
                        grammar[:bnf_transform],
                    ).then(
                        grammar[:bracket_insertion_ender]
                    )
                ),
            )
        )
        # any         ::= tabstop
        #                | placeholder
        #                | choice
        #                | variable
        #                | text
        grammar[:bnf_any] = Pattern.new(
            # NOTE: this second Pattern.new() is required as a workaround for a bug in ruby_grammar_builder
            #       (there can't be a backreference to group 0 e.g. top-level)
            Pattern.new(
                reference: "any",
                match: Pattern.new(
                    # 
                    # tabstop
                    # 
                    grammar[
                        :bnf_tabstop
                    # 
                    # choice
                    # 
                    ].or(
                        grammar[:bnf_choice]
                    # 
                    # placeholder
                    # 
                    ).or(
                        # NOTE: placeholder must be defined inline because it needs to have a backreference to "any"
                        # placeholder ::= '${' int ':' any '}'
                        Pattern.new(
                            tag_as: "#{bracket_insertion_tag} meta.insertion.placeholder",
                            match: Pattern.new(
                                grammar[:bracket_insertion_starter].then(
                                    grammar[:bnf_int]
                                ).then(
                                    grammar[:colon_separator]
                                ).then(
                                    oneOrMoreOf(
                                        recursivelyMatch("any")
                                    )
                                ).then(
                                    grammar[:bracket_insertion_ender]
                                )
                            ),
                            includes: [
                                # NOTE: must do these includes because the textmate engine seems broken (fails to highlight `${` of outer-most start)
                                #       ideally this whole "includes:" just wouldn't be needed
                                #       may have something to do with recursive regex
                                grammar[:bracket_insertion_starter].then(
                                    grammar[:bnf_int]
                                ).then(
                                    grammar[:colon_separator]
                                ),
                                :bracket_insertion_ender,
                                :bnf_any,
                            ]
                        )
                    # 
                    # variable
                    # 
                    ).or(
                        # NOTE: variable must be defined inline because it needs to have a backreference to "any"
                        # variable    ::= '$' var
                        #                 | '${' var '}'
                        #                 | '${' var ':' any '}'
                        #                 | '${' var transform '}'
                        Pattern.new(
                            # 
                            # case 1: '$' var
                            # 
                            Pattern.new(
                                tag_as: "#{simple_insertion_tag} meta.insertion.variable.simple",
                                should_fully_match: [ "$a", "$a2", ],
                                match: Pattern.new(
                                    Pattern.new(
                                        match:"$",
                                        tag_as: "punctuation.section.insertion.dollar.simple #{insertion_tag} custom.punctuation.section.insertion.dollar.simple",
                                    ).then(
                                        grammar[:bnf_var_simple]
                                    )
                                )
                            # 
                            # case 2: '${' var '}'
                            # 
                            ).or(
                                tag_as: "#{bracket_insertion_tag} meta.insertion.variable.bracket",
                                match: Pattern.new(
                                    grammar[:bracket_insertion_starter].then(
                                        grammar[:bnf_var_simple]
                                    ).then(
                                        grammar[:bracket_insertion_ender]
                                    )
                                ),
                            # 
                            # case 3: '${' var ':' any '}'
                            # 
                            ).or(
                                tag_as: "#{bracket_insertion_tag} meta.insertion.variable.any",
                                match: Pattern.new(
                                    grammar[:bracket_insertion_starter].then(
                                        grammar[:bnf_var]
                                    ).then(
                                        grammar[:colon_separator]
                                    ).then(
                                        match: oneOrMoreOf(recursivelyMatch("any")),
                                        includes: [
                                            :bnf_any,
                                        ]
                                    ).then(
                                        grammar[:bracket_insertion_ender]
                                    )
                                ),
                            # 
                            # case 4: '${' var ':' transform '}'
                            # 
                            ).or(
                                tag_as: "#{bracket_insertion_tag} meta.insertion.variable.transform",
                                match: Pattern.new(
                                    grammar[:bracket_insertion_starter].then(
                                        grammar[:bnf_var]
                                    ).then(
                                        tag_as: "meta.insertion.variable", # NOTE: repeated because VS Code's thing is broken
                                        # FIXME: NOTE: not really fixable
                                        #              this pattern should just be "grammar[:bnf_transform]"
                                        #              however this either causes time-complexity runtime problems
                                        #              or hits a bug in the VS Code textmate engine that causes it to fail
                                        #              below is a workaround/approximation that first tries to find the regex area
                                        #              then lets bnf_transform do the highlighting within that area
                                        #              this pattern could fail when the regex replacement contains something complicated,
                                        #              like another regex replacement
                                        match: Pattern.new(
                                            Pattern.new(
                                                Pattern.new(
                                                    "/"
                                                ).then(
                                                    oneOrMoreOf(
                                                        Pattern.new(
                                                            grammar[:regex_backslash_escape]
                                                        ).or(
                                                            /[^\/]/
                                                        )
                                                    )
                                                ).then(
                                                    "/"
                                                ).then(
                                                    /.*/
                                                ).then(
                                                    "/"
                                                ).then(
                                                    /[igmyu]{0,5}/
                                                ),
                                            ).or(
                                                grammar[:bnf_transform]
                                            )
                                        ),
                                        includes: [
                                            :bnf_transform,
                                        ],
                                    ).then(
                                        grammar[:bracket_insertion_ender]
                                    )
                                ),
                            )
                        )
                    # 
                    # text
                    # 
                    ).or(
                        tag_as: "meta.insertion.text",
                        match: grammar[:bnf_text]
                    )
                )
            )
        )
    # 
    # 
    # json modification
    # 
    # 
        # this part identifies
            # { "body": [ "THIS STRING" ] }
            # { "body": "THIS STRING" }
        # while leaving all of the other JSON strings alone
        # that string is then matched, and includes the snippet patterns
        grammar[:special_object_key] = PatternRange.new(
            start_pattern: Pattern.new(
                Pattern.new(
                    match: '"',
                    tag_as: "string support.type.property-name punctuation.support.type.property-name.begin",
                ).then(
                    match: 'body',
                    tag_as: "string support.type.property-name",
                ).then(
                    match: '"',
                    tag_as: "string support.type.property-name punctuation.support.type.property-name.begin",
                )
            ),
            end_pattern: lookBehindFor(/,/).or(lookAheadFor("}")),
            includes: [
                PatternRange.new(
                    tag_as: "meta.structure.dictionary.value",
                    start_pattern: Pattern.new(
                        Pattern.new(
                            match: ':',
                            tag_as: "punctuation.separator.dictionary.key-value"
                        )
                    ),
                    end_pattern: Pattern.new(
                        Pattern.new(
                            tag_as: "punctuation.separator.dictionary.pair",
                            match: /,/,
                        ).or(lookAheadFor(/\}/))
                    ),
                    includes: [
                        :body_value,
                        Pattern.new(
                            tag_as: "invalid.illegal.expected-dictionary-separator",
                            match: /[^\s,]/,
                        ),
                    ],
                ),
            ],
        )
        
        grammar[:body_stringcontent] = [
            Pattern.new(
                # match till end of string to bound the text area
                match: /(?:\\\\|\\"|[^"])++/,
                includes: [
                    :bnf_any,
                    :basic_escape,
                ]
            ),
            # :bnf_any_potential_insertion,
            # :simple_escape_context,
        ]
        
        grammar[:stringcontent] = grammar[:string_key_content] = [
            :basic_escape,
            :invalid_escape,
        ]
    
#
# save
#
name = "jsonc"
grammar.save_to(
    syntax_name: name,
    syntax_dir: "./autogenerated",
    tag_dir: "./autogenerated",
)