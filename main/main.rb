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
    part_of_a_variable = /[a-zA-Z_][a-zA-Z_0-9]*/
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
    simple_escape_context = [
        :null_quad_backslash,
        :dollar_sign_escape,
        :bracket_escape,
        :quad_backslash_match,
        :basic_escape,
        :invalid_escape,
        :normal_characters,
    ]
    # assuming there is no prior escape
    insertion_tag = "support.class.insertion"
    numeric_variable_tag = ""
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
    grammar[:naive_insertion_area] = Pattern.new(
        Pattern.new(
            reference: "naive_insertion",
            # 
            # $1, $howdy
            #
            match: Pattern.new(
                Pattern.new(
                    tag_as: "meta.insertion " + insertion_tag,
                    should_fully_match: [ "$1", "$2", "$howdeee" ],
                    match: Pattern.new("$").oneOf([
                        /\d+/,
                        /[a-zA-Z0-9_]+/, # FIXME: this might should include more characters
                    ]),
                # 
                # ${1|one,two,three|}
                # 
                ).or(
                    Pattern.new(
                        tag_as: "meta.insertion " + insertion_tag,
                        should_fully_match: [ "${1|one,two,three|}", ],
                        match: Pattern.new(
                            Pattern.new(
                                match: "$",
                                tag_as: "meta.insertion " + "punctuation.section.insertion.dollar #{insertion_tag}",
                            ).then(
                                tag_as: "meta.insertion " + "punctuation.section.insertion",
                                match: "{",
                            ).then(
                                match: /\d+/,
                                tag_as: numeric_variable_tag,
                            ).then(
                                tag_as: "meta.insertion " + "punctuation.separator.choice",
                                match: "|",
                            ).then(
                                match: /.+?/,
                                includes: [
                                    Pattern.new(
                                        tag_as: "meta.insertion " + "punctuation.separator.comma",
                                        match: ","
                                    ),
                                    Pattern.new(
                                        tag_as: "meta.insertion " + "constant.other.option",
                                        match: Pattern.new(
                                            /.+?/
                                        ).lookAheadFor(/,/)
                                    ),
                                    Pattern.new(
                                        tag_as: "meta.insertion " + "constant.other.option",
                                        match: Pattern.new(
                                            /.+?\z/
                                        )
                                    ),
                                ],
                            ).then(
                                tag_as: "meta.insertion " + "punctuation.separator.choice",
                                match: "|",
                            ).then(
                                tag_as: "meta.insertion " + "punctuation.section.insertion",
                                match: "}",
                            )
                        )
                    )
                # 
                # Variable transforms: ${TM_FILENAME/(.*)\\..+$/$1/}
                # 
                ).or(
                    Pattern.new(
                        tag_as: "meta.insertion " + insertion_tag+" meta.variable-transform",
                        should_fully_match: [ "${TM_FILENAME/(.*)\\..+$/$1/}", ],
                        match: Pattern.new(
                            Pattern.new(
                                match: "$",
                                tag_as: "meta.insertion " + "punctuation.section.insertion.dollar #{insertion_tag}",
                            ).then(
                                tag_as: "meta.insertion " + "punctuation.section.insertion",
                                match: "{",
                            ).then(
                                match: /\w+/,
                                tag_as: "variable.other.normal",
                            ).then(
                                tag_as: "meta.insertion " + "string.regexp",
                                # FIXME: this is an incomplete pattern,
                                #        generally when something is wrong/broken VS Code will fallback to just treating it as a string
                                #        so this pattern needs to literally fully parse everything including all possible invalid cases
                                #        and know when a case will be invalid before hand, all in pure regex
                                #        Right now it does not do that, and instead focuses on the valid case
                                # 
                                #        known caveats: escaping the \} from ${} while also escaping it for JSON and for regex
                                match: Pattern.new(
                                    Pattern.new(
                                        match: "/",
                                        tag_as: "meta.insertion " + "punctuation.section.regexp",
                                    ).then(
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
                                            *simple_escape_context,
                                        ],
                                    ).then(
                                        match: "/",
                                        tag_as: "meta.insertion " + "punctuation.section.regexp",
                                    ).then(
                                        match: oneOrMoreOf(
                                            # regex escape or anything thats not a slash
                                            match: grammar[:regex_backslash_escape].or(/[^\/\n]/),
                                            # dont_back_track?: false,
                                        ),
                                        includes: [
                                            Pattern.new(
                                                tag_as: "meta.insertion " + "variable.language.capture",
                                                match: /\$\d+/,
                                            ),
                                            :basic_escape,
                                            # TODO: should also include other escape sequences
                                        ]
                                    ).then(
                                        match: "/",
                                        tag_as: "meta.insertion " + "punctuation.section.regexp",
                                    ).then(
                                        tag_as: "meta.insertion " + "keyword.other.flag",
                                        match: /[igmyu]{0,5}/,
                                    ).lookAheadFor("}")
                                )
                            ).then(
                                tag_as: "meta.insertion " + "punctuation.section.insertion",
                                match: "}",
                            )
                        )
                    )
                ).or(
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
                        tag_as: "meta.insertion " + insertion_tag,
                        match: Pattern.new(
                            Pattern.new(
                                tag_as: "meta.insertion " + "punctuation.section.insertion",
                                match: /\$\{/,
                            ).then(
                                tag_as: numeric_variable_tag,
                                match: /\d+/,
                            ).then(
                                tag_as: "meta.insertion " + "punctuation.section.insertion",
                                match: /:/,
                            )
                        ),
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
                                *simple_escape_context
                            ],
                        )
                    ).then(
                        tag_as: "meta.insertion " + insertion_tag + " punctuation.section.insertion",
                        match: "}",
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
                        *simple_escape_context,
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
                *simple_escape_context, # includes $ escape
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
        :any_potential_insertion,
        *simple_escape_context,
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