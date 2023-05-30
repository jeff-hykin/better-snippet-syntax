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
# Setup Grammar
#
# 
    grammar[:$initial_context] = [
        :value,
    ]

# 
# Helpers
# 
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
    part_of_a_variable = /[_a-zA-Z][_a-zA-Z0-9]*/
    # this is really useful for keywords. eg: variableBounds[/new/] wont match "newThing" or "thingnew"
    variableBounds = ->(regex_pattern) do
        lookBehindToAvoid(@standard_character).then(regex_pattern).lookAheadToAvoid(@standard_character)
    end
    variable = variableBounds[part_of_a_variable]
    
# 
# basic patterns
# 
    # overwrite the stringcontent
    normal_escape_tag = "constant.character.escape.json.comments"
    outputs_just_a_backslash_tag = "entity.name.escape.backslash.insertion.json.comments"
    double_escaper_tag = "punctuation.section.insertion.escape.escaper.json.comments comment.block punctuation.definition.comment.insertion.escape.json.comments"
    double_escapee_tag = "punctuation.section.insertion.escape.escapee.json.comments string.regexp.insertion.escape.json.comments"
    normal_string_charater_tag = "string.quoted.double.json.comments"
    insertion_tag = "support.class.insertion"
    numeric_variable_tag = "variable.other.normal.numeric"
    named_variable_tag = "variable.other.normal"
    
    grammar[:basic_escape] = Pattern.new(
        tag_as: normal_escape_tag,
        match: Pattern.new(/\\/).then(
            Pattern.new(/["\\\/bfnrt]/).or(/u[0-9a-fA-F]{4}/)
        ),
    )
    grammar[:invalid_escape] = Pattern.new(
        tag_as: "invalid.illegal.unrecognized-string-escape.json.comments",
        match: Pattern.new(/\\\\./),
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
        match: lookBehindToAvoid(/\\/).zeroOrMoreOf(match: /\\\\\\\\/, no_backtrack: true).then(
            Pattern.new(/\\\\/).then("$")
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
        tag_as: normal_string_charater_tag,
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
    grammar[:bracket_insertion_starter] = Pattern.new(
        Pattern.new(
            tag_as: "punctuation.section.insertion.dollar.interpolated #{insertion_tag}",
            match: "$",
        ).then(
            tag_as: "punctuation.section.insertion.bracket #{insertion_tag}",
            match: "{",
        )
    )
    grammar[:bracket_insertion_ender] = Pattern.new(
        Pattern.new(
            tag_as: "punctuation.section.insertion.bracket #{insertion_tag}",
            match: "}",
        )
    )
    grammar[:choice_option] = Pattern.new(
        tag_as: "constant.other.option",
        reference: "choice_text",
        match: oneOrMoreOf(
            grammar[:quad_backslash_match].or(
                Pattern.new(
                    match: /\/\//,
                    tag_as: double_escaper_tag,
                ).then(
                    /\,|\|/
                )
            ).or(
                oneOf([
                    grammar[:null_quad_backslash],
                    grammar[:dollar_sign_escape],
                    grammar[:bracket_escape],
                    grammar[:quad_backslash_match],
                    grammar[:basic_escape],
                ])
            ).or(
                /[^,\|]++/
            )
        ),
    )
    grammar[:colon_separator] = Pattern.new(
        tag_as: "punctuation.section.insertion punctuation.separator.colon #{insertion_tag}",
        match: ":",
    )
    grammar[:special_insertions] = Pattern.new(
        Pattern.new(
            tag_as: "punctuation.section.insertion.dollar.connected #{insertion_tag} variable.language.this",
            match: "$",
        ).then(
            tag_as: "#{insertion_tag} variable.language.this",
            match: variableBounds[/TM_SELECTED_TEXT|TM_CURRENT_LINE|TM_CURRENT_WORD|TM_LINE_INDEX|TM_LINE_NUMBER|TM_FILENAME|TM_FILENAME_BASE|TM_DIRECTORY|TM_FILEPATH|RELATIVE_FILEPATH|CLIPBOARD|WORKSPACE_NAME|WORKSPACE_FOLDER|CURSOR_INDEX|CURSOR_NUMBER|CURRENT_YEAR|CURRENT_YEAR_SHORT|CURRENT_MONTH|CURRENT_MONTH_NAME|CURRENT_MONTH_NAME_SHORT|CURRENT_DATE|CURRENT_DAY_NAME|CURRENT_DAY_NAME_SHORT|CURRENT_HOUR|CURRENT_MINUTE|CURRENT_SECOND|CURRENT_SECONDS_UNIX|CURRENT_TIMEZONE_OFFSET|RANDOM|RANDOM_HEX|UUID|BLOCK_COMMENT_START|BLOCK_COMMENT_END|LINE_COMMENT/],
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
    # BNF form
    # 
    # 
        # VS Code problems
        # 1. placeholder overrides choice (wrong order, choice must be higher)
        # 2. text is broken, doesn't include/mention any escapes and behaves non-greedily
        # 3. in choice, the options are allow to recursively contain other insertions with weird broken behavior
        # 4. transform, the regex-replace area allows empty regex (but the BNF doesnt)
        # 5. transform, the regex-replace area doesn't mention the special regex-replacement names like $1
    # https://code.visualstudio.com/docs/editor/userdefinedsnippets#_placeholdertransform
        grammar[:int]    = Pattern.new(
            tag_as: numeric_variable_tag,
            match: /[0-9]+/,
        )
        grammar[:int_simple]    = Pattern.new(
            tag_as: numeric_variable_tag + " #{insertion_tag}",
            match: /[0-9]+/,
        )
        grammar[:text]   = Pattern.new(
            tag_as: "text.$match",
            match: maybe(grammar[:simple_escape_context].or(/[^\n\r]/)).zeroOrMoreOf(
                as_few_as_possible?: true,
                match: grammar[:simple_escape_context].or(/[^\n\r]/),
            ),
            includes: [
                :special_insertions,
                :simple_escape_context,
            ]
        )
        grammar[:var]    = Pattern.new(
            tag_as: named_variable_tag,
            match: variableBounds[/[_a-zA-Z][_a-zA-Z0-9]*/],
        )
        grammar[:var_simple]    = Pattern.new(
            tag_as: named_variable_tag + " #{insertion_tag}",
            match: variableBounds[/[_a-zA-Z][_a-zA-Z0-9]*/],
        )
        
        # choice ::= '${' int '|' text (',' text)* '|}'
        grammar[:choice] = Pattern.new(
            tag_as: "meta.insertion.choice",
            match: Pattern.new(
                grammar[:bracket_insertion_starter].then(
                    grammar[:int]
                ).then(
                    tag_as: "punctuation.separator.choice" + " #{insertion_tag}",
                    match: "|",
                ).then(
                    # NOTE: functionally VS Code allows choice_option to recursively include more insertions
                    #       however that functionality goes against its own extended Backus-Naur form specification
                    #       this highligher doesn't support the functionality
                    grammar[:choice_option].then(
                        match: zeroOrMoreOf(
                            as_few_as_possible?: true,
                            match: Pattern.new(
                                Pattern.new(
                                    match: ","
                                ).then(
                                    recursivelyMatch("choice_text")
                                )
                            ),
                        ),
                        includes: [
                            :choice_option,
                            Pattern.new(
                                tag_as: "punctuation.separator.comma",
                                match: ","
                            ),
                        ]
                    )
                ).then(
                    tag_as: "punctuation.separator.choice" + " #{insertion_tag}",
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
        grammar[:format] = Pattern.new(
            # 
            # case 1: '$' int
            # 
            grammar[:special_insertions].or(
                tag_as: "meta.insertion.simple",
                should_fully_match: [ "$1", "$2", ],
                match: Pattern.new(
                    Pattern.new(
                        match:"$",
                        tag_as: "punctuation.section.insertion.dollar.connected #{insertion_tag}",
                    ).then(
                        grammar[:int_simple]
                    )
                )
            # 
            # case 2: '${' int ':' '/upcase' | '/downcase' | '/capitalize' | '/camelcase' | '/pascalcase' '}'
            # 
            ).or(
                tag_as: "meta.insertion.transform",
                match: Pattern.new(
                    grammar[:bracket_insertion_starter].then(
                        grammar[:int]
                    ).then(
                        grammar[:colon_separator]
                    ).then(
                        Pattern.new(
                            tag_as: "punctuation.section.regexp support.type.built-in variable.language.special",
                            match: //,
                        ).then(
                            tag_as: "support.type.built-in variable.language.special",
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
                tag_as: "meta.insertion.transform",
                match: Pattern.new(
                    grammar[:bracket_insertion_starter].then(
                        grammar[:int]
                    ).then(
                        grammar[:colon_separator]
                    ).then(
                        tag_as: "punctuation.separator.plus",
                        match: "+",
                    ).then(
                        grammar[:text]
                    ).then(
                        grammar[:bracket_insertion_ender]
                    )
                ),
            # 
            # case 4: '${' int ':?' text ':' text '}'
            # 
            ).or(
                tag_as: "meta.insertion.transform",
                match: Pattern.new(
                    grammar[:bracket_insertion_starter].then(
                        grammar[:int]
                    ).then(
                        grammar[:colon_separator]
                    ).then(
                        tag_as: "punctuation.separator.conditional keyword.operator.ternary",
                        match: "?",
                    ).then(
                        grammar[:text]
                    ).then(
                        tag_as: "keyword.operator.ternary",
                        match: /:/,
                    ).then(
                        grammar[:text]
                    ).then(
                        grammar[:bracket_insertion_ender]
                    )
                ),
            # 
            # case 5: '${' int ':-' text '}'
            # 
            ).or(
                tag_as: "meta.insertion.transform",
                match: Pattern.new(
                    grammar[:bracket_insertion_starter].then(
                        grammar[:int]
                    ).then(
                        grammar[:colon_separator]
                    ).then(
                        tag_as: "punctuation.separator.dash",
                        match: "-",
                    ).then(
                        grammar[:text]
                    ).then(
                        grammar[:bracket_insertion_ender]
                    )
                ),
            # 
            # case 6: '${' int ':' text '}'
            # 
            ).or(
                tag_as: "meta.insertion.transform",
                match: Pattern.new(
                    grammar[:bracket_insertion_starter].then(
                        grammar[:int]
                    ).then(
                        grammar[:colon_separator]
                    ).then(
                        grammar[:text]
                    ).then(
                        grammar[:bracket_insertion_ender]
                    )
                ),
            )
        )
        # transform   ::= '/' REGEX '/' (format | text )+ '/' REGEX_OPTIONS
        grammar[:transform] = Pattern.new(
            # 
            # finding: /THIS/WHOLE THING/
            # 
            tag_as: "string.regexp",
            # FIXME: this is an unconfirmed pattern that is probably incomplete
            #        generally when something is wrong/broken VS Code will fallback to just treating it as a string
            #        so this pattern needs to literally fully parse everything including all possible invalid cases
            #        and know when a case will be invalid before hand, all in pure regex
            #        Right now it does not do that, and instead focuses on the valid case
            # 
            #        concerns: escaping the \} from ${} while also escaping it for JSON and for regex
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
                        match: grammar[:format].or(
                            grammar[:regex_backslash_escape].or(
                                grammar[:text]
                            ),
                        ),
                        # dont_back_track?: false,
                    ),
                    includes: [
                        Pattern.new(
                            tag_as: "variable.language.capture",
                            match: /\$\d+/,
                        ),
                        :basic_escape,
                        :simple_escape_context,
                        # TODO: should also include other escape sequences
                    ]
                ).then(
                    match: "/",
                    tag_as: "punctuation.section.regexp",
                ).maybe(
                    @spaces
                ).then(
                    tag_as: "keyword.other.flag",
                    match: /[igmyu]{0,5}/,
                ).lookAheadFor("}")
            )
        )
        # tabstop     ::= '$' int
        #     | '${' int '}'
        #     | '${' int  transform '}'
        grammar[:tabstop] = Pattern.new(
            tag_as: "meta.insertion.tabstop",
            match: Pattern.new(
                # 
                # case 1: '$' int
                # 
                Pattern.new(
                    should_fully_match: [ "$1", "$2", ],
                    match: Pattern.new(
                        Pattern.new(
                            match:"$",
                            tag_as: "punctuation.section.insertion.dollar.connected #{insertion_tag}",
                        ).then(
                            grammar[:int_simple]
                        )
                    )
                # 
                # case 2: '${' int '}'
                # 
                ).or(
                    tag_as: "meta.insertion", # FIXME rename tags
                    match: Pattern.new(
                        grammar[:bracket_insertion_starter].then(
                            grammar[:int_simple]
                        ).then(
                            grammar[:bracket_insertion_ender]
                        )
                    ),
                # 
                # case 3: '${' int  transform '}'
                # 
                ).or(
                    tag_as: "meta.insertion", # FIXME rename tags
                    match: Pattern.new(
                        grammar[:bracket_insertion_starter].then(
                            grammar[:int]
                        ).then(
                            grammar[:transform]
                        ).then(
                            grammar[:bracket_insertion_ender]
                        )
                    ),
                )
            ),
        )
        
        # any         ::= tabstop
        #                | placeholder
        #                | choice
        #                | variable
        #                | text
        grammar[:any] = Pattern.new(
            Pattern.new(
                reference: "any",
                match: Pattern.new(
                    # 
                    # tabstop
                    # 
                    grammar[:tabstop].or(
                    
                    # 
                    # choice
                    # 
                        grammar[:choice]
                    # 
                    # placeholder
                    # 
                    ).or(
                        # placeholder ::= '${' int ':' any '}'
                        Pattern.new(
                            tag_as: "meta.insertion.placeholder",
                            match: Pattern.new(
                                grammar[:bracket_insertion_starter].then(
                                    grammar[:int]
                                ).then(
                                    match: recursivelyMatch("any"),
                                    includes: [
                                        :any,
                                    ]
                                ).then(
                                    grammar[:bracket_insertion_ender]
                                )
                            )
                        )
                    # 
                    # variable
                    # 
                    ).or(
                        Pattern.new(
                            reference: "variable",
                            match: Pattern.new(
                                # 
                                # case 1: '$' var
                                # 
                                Pattern.new(
                                    tag_as: "meta.insertion.variable", # FIXME
                                    should_fully_match: [ "$a", "$a2", ],
                                    match: Pattern.new(
                                        Pattern.new(
                                            match:"$",
                                            tag_as: "punctuation.section.insertion.dollar.connected #{insertion_tag}",
                                        ).then(
                                            grammar[:var_simple]
                                        )
                                    )
                                # 
                                # case 2: '${' var '}'
                                # 
                                ).or(
                                    tag_as: "meta.insertion.variable",
                                    match: Pattern.new(
                                        grammar[:bracket_insertion_starter].then(
                                            grammar[:var_simple]
                                        ).then(
                                            grammar[:bracket_insertion_ender]
                                        )
                                    ),
                                # 
                                # case 3: '${' var ':' any '}'
                                # 
                                ).or(
                                    tag_as: "meta.insertion.variable",
                                    match: Pattern.new(
                                        grammar[:bracket_insertion_starter].then(
                                            grammar[:var]
                                        ).then(
                                            grammar[:colon_separator]
                                        ).then(
                                            match: recursivelyMatch("any"),
                                            includes: [
                                                :any,
                                            ]
                                        ).then(
                                            grammar[:bracket_insertion_ender]
                                        )
                                    ),
                                # 
                                # case 4: '${' var ':' transform '}'
                                # 
                                ).or(
                                    tag_as: "meta.insertion.variable",
                                    match: Pattern.new(
                                        grammar[:bracket_insertion_starter].then(
                                            grammar[:var]
                                        ).then(
                                            grammar[:transform]
                                        ).then(
                                            grammar[:bracket_insertion_ender]
                                        )
                                    ),
                                )
                            )
                        )
                    # 
                    # text
                    # 
                    ).or(
                        tag_as: "meta.insertion.text",
                        match: grammar[:text]
                    )
                )
            )
        )
    
    # assuming there is no prior escape
    grammar[:naive_insertion_area] = Pattern.new(
        Pattern.new(
            should_fully_match: [
                "$1",
                "$2",
                "$howdeee",
                "${TM_FILENAME/(.*)/${1:/upcase}/}",
            ],
            reference: "naive_insertion",
            match: Pattern.new(
                # 
                # $1, $howdy
                #
                grammar[:special_insertions].or(
                    
                    tag_as: "meta.insertion.simple",
                    should_fully_match: [ "$1", "$2", "$howdeee" ],
                    match: Pattern.new(
                        Pattern.new(
                            match:"$",
                            tag_as: "punctuation.section.insertion.dollar.connected #{insertion_tag}",
                        ).then(
                            Pattern.new(
                                tag_as: numeric_variable_tag + " #{insertion_tag}",
                                match: /\d+\b/,
                            ).or(
                                tag_as: named_variable_tag + " #{insertion_tag}",
                                match: /[a-zA-Z0-9_]+/, # FIXME: this might should include more characters
                            )
                        )
                    )
                # 
                # ${1|one,two,three|}
                # 
                ).or(
                    Pattern.new(
                        tag_as: "meta.insertion.choice",
                        should_fully_match: [ "${1|one,two,three|}", ],
                        match: Pattern.new(
                            Pattern.new(
                                match: "$",
                                tag_as: "punctuation.section.insertion.dollar.interpolated #{insertion_tag}",
                            ).then(
                                tag_as: "punctuation.section.insertion.bracket #{insertion_tag}",
                                match: "{",
                            ).then(
                                match: /\d+/,
                                tag_as: numeric_variable_tag + " #{insertion_tag}",
                            ).then(
                                tag_as: "punctuation.separator.choice" + " #{insertion_tag}",
                                match: "|",
                            ).then(
                                match: /.+?/,
                                includes: [
                                    Pattern.new(
                                        tag_as: "punctuation.separator.comma",
                                        match: ","
                                    ),
                                    Pattern.new(
                                        tag_as: "constant.other.option",
                                        match: Pattern.new(
                                            /.+?/
                                        ).lookAheadFor(/,/)
                                    ),
                                    Pattern.new(
                                        tag_as: "constant.other.option",
                                        match: Pattern.new(
                                            /.+?\z/
                                        )
                                    ),
                                ],
                            ).then(
                                tag_as: "punctuation.separator.choice" + " #{insertion_tag}",
                                match: "|",
                            ).then(
                                tag_as: "punctuation.section.insertion.bracket"+ " #{insertion_tag}",
                                match: "}",
                            )
                        )
                    )
                # 
                # Variable transforms: ${TM_FILENAME/(.*)\\..+$/$1/}
                # 
                ).or(
                    Pattern.new(
                        tag_as: "meta.insertion.variable-transform",
                        should_fully_match: [
                            "${TM_FILENAME/(.*)\\..+$/$1/}", 
                            "${TM_FILENAME/[\\\\.]/_/}",
                            "${TM_FILENAME/[\\\\.-]/_/g}",
                            "${TM_FILENAME/[^0-9^a-z]//gi}",
                            # "${A1:/upcase}",
                            # NOTE: the following case should also work BUT not as a unit test
                            # because there is a recursive reference to a parent pattern
                            # but parent patterns don't exist for unit tests (otherwise they wouldn't be a unit test)
                            #    "${TM_FILENAME/(.*)/${1:/upcase}/}"
                        ],
                        match: Pattern.new(
                            Pattern.new(
                                tag_as: "punctuation.section.insertion.dollar.interpolated #{insertion_tag}",
                                match: "$",
                            ).then(
                                tag_as: "punctuation.section.insertion.bracket #{insertion_tag}",
                                match: "{",
                            ).then(
                                tag_as: named_variable_tag + " #{insertion_tag}",
                                match: variable,
                            ).then(
                                # 
                                # finding: /THIS/WHOLE THING/
                                # 
                                tag_as: "string.regexp",
                                # FIXME: this is an unconfirmed pattern that is probably incomplete
                                #        generally when something is wrong/broken VS Code will fallback to just treating it as a string
                                #        so this pattern needs to literally fully parse everything including all possible invalid cases
                                #        and know when a case will be invalid before hand, all in pure regex
                                #        Right now it does not do that, and instead focuses on the valid case
                                # 
                                #        concerns: escaping the \} from ${} while also escaping it for JSON and for regex
                                match: Pattern.new(
                                    # 
                                    # edgecases
                                    # 
                                    Pattern.new(
                                        Pattern.new(
                                            tag_as: "punctuation.section.regexp support.type.built-in variable.language.special",
                                            match: //,
                                        ).then(
                                            tag_as: "support.type.built-in variable.language.special",
                                            match: /upcase|downcase|capitalize|camelcase|pascalcase/,
                                            reference: "builtin_replacement_name",
                                        ).then(/\b/)
                                    # 
                                    # normal case
                                    # 
                                    ).or(
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
                                                match: recursivelyMatch("naive_insertion").or(
                                                    grammar[:regex_backslash_escape].or(
                                                        /[^\/\n]/
                                                    ),
                                                ),
                                                # dont_back_track?: false,
                                            ),
                                            includes: [
                                                Pattern.new(
                                                    tag_as: "variable.language.capture",
                                                    match: /\$\d+/,
                                                ),
                                                :basic_escape,
                                                :naive_insertion_area,
                                                # TODO: should also include other escape sequences
                                            ]
                                        ).then(
                                            match: "/",
                                            tag_as: "punctuation.section.regexp",
                                        ).then(
                                            tag_as: "keyword.other.flag",
                                            match: /[igmyu]{0,5}/,
                                        ).lookAheadFor("}")
                                    ),
                                )
                            ).then(
                                tag_as: "punctuation.section.insertion.bracket #{insertion_tag}",
                                match: "}",
                            )
                        )
                    )
                ).or(
                    # 
                    # ${thing:default}
                    # 
                    Pattern.new(
                        tag_as: "meta.insertion.default",
                        match: Pattern.new(
                            # key question is: what results in an inert/unmatched ${}
                                # "${}"               => ${}
                                # "${:}"              => ${:}
                                # "${:a}"             => ${:a}
                                # "${0:}"             => special
                                # "${0:\\}"           => ${0:}
                                # "${0:\\a}"          => \a and special
                                # "${0:\\\\}"         => \ and special
                                # "${0:\\\\a}"        => \a and special
                                # "${0:\\\\\\}"       => ${0:\}
                                # "${0:\\\\\\\\}"     => \\ and special
                                # "${0:\\\\\\\\a}"    => \\a and special
                                # "${0:\\}\\\\\\a}"   => }\\a and special
                                # "${0:\\}\\\\\\a}"   => }\\a and special
                                # "${0:\\\\}\\\\\\a}" => \\\a} and first slash special
                                # "${0:$}"            => $ and first slash special(
                            Pattern.new(
                                Pattern.new(
                                    tag_as: "punctuation.section.insertion.dollar.interpolated #{insertion_tag}",
                                    match: /\$/,
                                ).then(
                                    tag_as: "punctuation.section.insertion.bracket #{insertion_tag}",
                                    match: /\{/,
                                ).then(
                                    tag_as: numeric_variable_tag + " #{insertion_tag}",
                                    match: /\d+/,
                                ).then(
                                    tag_as: "punctuation.section.insertion #{insertion_tag}",
                                    match: /:/,
                                )
                            ).then(
                                match: zeroOrMoreOf(
                                    match: oneOf([
                                        recursivelyMatch("naive_insertion"),
                                        grammar[:bracket_escape], 
                                        /[^\\\n\}"]/,             # a primitive character, including $
                                        /(?:\\\\\\\\)++/,         # a quadruple backslash (ends up as a slash)
                                        /\\\\[^\\\n\}]/,          # a double-backslash escaped normal thing
                                        grammar[:basic_escape].lookBehindToAvoid(/\\/),   # a normal json escape, that is not a \\ escape
                                    ]),
                                    includes: [
                                        :naive_insertion_area,
                                        :simple_escape_context,
                                    ],
                                )
                            ).then(
                                tag_as: " punctuation.section.insertion.bracket #{insertion_tag}",
                                match: "}",
                            )
                        )
                    )
                ),
            )
        )
    )
    # every possible match or failed-match of insertion area
    grammar[:any_potential_insertion] = Pattern.new(
        Pattern.new(
            # given the $ would be active (if no backslashes given)
                # "$1"               => 1 is special
                # "\\$1"             => $1
                # "\\\\$1"           => \ and 1 is special
                # "\\\\\\$1"         => \$1
            # logic
                # all quad slashes means the $ is 
            match: oneOf([
                grammar[:naive_insertion_area],
                # exclusively quad backslashes, meaning the insertion area is still active
                Pattern.new(
                    match: zeroOrMoreOf(match: /\\\\\\\\/, no_backtrack: true).then(grammar[:naive_insertion_area]),
                    includes: [
                        grammar[:naive_insertion_area],
                        :quad_backslash_match,
                    ]
                ),
                # double backslash, then quad backslashes, meaning the insertion area is NOT active
                Pattern.new(
                    match: Pattern.new(/\\\\/).zeroOrMoreOf(match: /\\\\\\\\/, no_backtrack: true).then(grammar[:naive_insertion_area]),
                    includes: [
                        :simple_escape_context,
                    ]
                ),
            ]),
        ).or(
        # given the $ after the slashes would be inert
            # 
            # "$"                => $
            # "$$"               => $$
            # "\\$"              => $
            # "\\\\$"            => \$
            # "\\\\\\$"          => \$
            # "\\\\\\\\$$ 1"     => \\$$ 1
            # "$$1"              => $ and 1 is special
            # "\\\\\\$$1"        => \$ and 1 is special
            # "\\\\$$abra 1"     => \$ and abra is special
            # "\\\\\\$$abra 1"   => \$ and abra is special
            # "\\\\\\\\$$abra 1" => \\$ and abra is special
            match: zeroOrMoreOf(match:/\\\\/, no_backtrack: true).then("$"),
            includes: [
                :simple_escape_context, # includes $ escape
                # unpaired } without escapes
                Pattern.new(
                    tag_as: normal_string_charater_tag,
                    match: "}",
                ),
            ],
        )
    )
    
    grammar[:special_object_key] = PatternRange.new(
        start_pattern: Pattern.new(
            Pattern.new(
                match: '"',
                tag_as: "string.json.comments support.type.property-name.json.comments punctuation.support.type.property-name.begin.json.comments",
            ).then(
                match: 'body',
                tag_as: "string.json.comments support.type.property-name.json.comments",
            ).then(
                match: '"',
                tag_as: "string.json.comments support.type.property-name.json.comments punctuation.support.type.property-name.begin.json.comments",
            )
        ),
        end_pattern: lookBehindFor(/,/).or(lookAheadFor("}")),
        includes: [
            PatternRange.new(
                tag_as: "meta.structure.dictionary.value.json.comments",
                start_pattern: Pattern.new(
                    Pattern.new(
                        match: ':',
                        tag_as: "punctuation.separator.dictionary.key-value.json.comments"
                    )
                ),
                end_pattern: Pattern.new(
                    Pattern.new(
                        tag_as: "punctuation.separator.dictionary.pair.json.comments",
                        match: /,/,
                    ).or(lookAheadFor(/\}/))
                ),
                includes: [
                    :body_value,
                    Pattern.new(
                        tag_as: "invalid.illegal.expected-dictionary-separator.json.comments",
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
                :any
            ]
        ),
        # :any_potential_insertion,
        # :simple_escape_context,
    ]
    
    grammar[:stringcontent] = grammar[:string_key_content] = [
        :basic_escape,
        :invalid_escape,
    ]
    
#
# Save
#
name = "jsonc"
grammar.save_to(
    syntax_name: name,
    syntax_dir: "./autogenerated",
    tag_dir: "./autogenerated",
)