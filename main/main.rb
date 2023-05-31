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
    choice_meta_tag = "meta.insertion.choice"
    grammar[:choice_option] = Pattern.new(
        tag_as: "#{choice_meta_tag} constant.other.option", # NOTE: shouldn't need this choice_meta_tag (redundant) but textmate engine seems to have a problem and this is a workaround
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
            match: maybe(grammar[:simple_escape_context]).zeroOrMoreOf(
                as_few_as_possible?: true,
                match: grammar[:simple_escape_context],
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
                tag_as: "meta.insertion.format.simple",
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
                tag_as: "meta.insertion.format.transform",
                match: Pattern.new(
                    grammar[:bracket_insertion_starter].then(
                        grammar[:int]
                    ).then(
                        grammar[:colon_separator]
                    ).then(
                        Pattern.new(
                            tag_as: "punctuation.section.regexp support.type.built-in variable.language.special",
                            match: /\//,
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
                tag_as: "meta.insertion.format.plus",
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
                tag_as: "meta.insertion.format.conditional",
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
                tag_as: "meta.insertion.format.remove",
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
                tag_as: "meta.insertion.format.default",
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
            tag_as: "meta.insertion.transform string.regexp",
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
                                Pattern.new(
                                    tag_as: "text.$match",
                                    match: zeroOrMoreOf(
                                        match: grammar[:simple_escape_context].or(/[^\n\r]/),
                                    ),
                                    includes: [
                                        :special_insertions,
                                        :simple_escape_context,
                                    ]
                                )
                            ),
                        ),
                        # dont_back_track?: false,
                    ),
                    includes: [
                        Pattern.new(
                            tag_as: "variable.language.capture",
                            match: /\$\d+/,
                        ),
                        :format,
                        :regex_backslash_escape,
                        :text,
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
                            tag_as: "meta.insertion",
                            match: grammar[:transform],
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
                                    grammar[:colon_separator]
                                ).then(
                                    match: oneOrMoreOf(
                                        recursivelyMatch("any")
                                    ),
                                ).then(
                                    grammar[:bracket_insertion_ender]
                                )
                            ),
                            includes: [
                                # must do these includes because the textmate engine seems broken (fails to highlight `${` of outer-most start)
                                grammar[:bracket_insertion_starter].then(
                                    grammar[:int]
                                ).then(
                                    grammar[:colon_separator]
                                ),
                                :bracket_insertion_ender,
                                :any,
                            ]
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
                                            match: oneOrMoreOf(recursivelyMatch("any")),
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
                                            tag_as: "meta.insertion.variable", # repeated because VS Code's thing is broken
                                            match: Pattern.new(/\/.+\/.*\/[igmyu]{0,5}/).or(grammar[:transform]),
                                            includes: [
                                                :transform,
                                                # grammar[:transform]
                                            ],
                                            # match: grammar[:transform],
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