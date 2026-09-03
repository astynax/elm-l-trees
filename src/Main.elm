module Main exposing (main, suite)

import Browser
import Dict exposing (Dict)
import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Html exposing (Html)
import Html.Attributes as HA
import Html.Events as HE
import Parser as P exposing (Parser, grab, ignore)
import Parser.Common as PC
import Result
import Test exposing (..)


type Msg
    = EditRules String
    | EditSeed String
    | Step


type alias Model =
    { rules : Result String Rules
    , rulesInput : String
    , seedInput : String
    , dirty : Bool
    , pattern : List String
    }


type alias Rules =
    { blockWidth : Int
    , blockHeight : Int
    , mapping : Dict Char (List String)
    }


normalizeRules : Dict Char (List String) -> Rules
normalizeRules rawRules =
    let
        allBlocks =
            Dict.values rawRules

        blockHeight =
            allBlocks
                |> List.map List.length
                |> List.maximum
                |> Maybe.withDefault 0

        blockWidth =
            allBlocks
                |> List.concat
                |> List.map String.length
                |> List.maximum
                |> Maybe.withDefault 0

        padBlock block =
            let
                paddedLines =
                    List.map (String.padRight blockWidth ' ') block

                extraLinesCount =
                    max 0 (blockHeight - List.length block)

                emptyLine =
                    String.repeat blockWidth " "

                extraLines =
                    List.repeat extraLinesCount emptyLine
            in
            paddedLines ++ extraLines

        normalizedMapping =
            Dict.map (\_ block -> padBlock block) rawRules
    in
    { blockWidth = blockWidth
    , blockHeight = blockHeight
    , mapping = normalizedMapping
    }


main : Program () Model Msg
main =
    Browser.sandbox { init = init, view = view, update = update }


view : Model -> Html Msg
view model =
    Html.div []
        [ Html.label [] [ Html.text "Rules" ]
        , Html.textarea
            [ HA.value model.rulesInput
            , HE.onInput EditRules
            , HA.rows 10
            , HA.cols 40
            ]
            []
        , Html.label [] [ Html.text "Seed" ]
        , Html.textarea
            [ HA.value model.seedInput
            , HE.onInput EditSeed
            , HA.rows 5
            , HA.cols 40
            ]
            []
        , Html.button [ HE.onClick Step ] [ Html.text "Step" ]
        , Html.pre [] [ Html.text (String.join "\n" model.pattern) ]
        ]


stitchRow : List (List String) -> List String
stitchRow blocks =
    case blocks of
        [] ->
            []

        first :: rest ->
            List.foldl (\block acc -> List.map2 (++) acc block) first rest


render : List String -> Rules -> List String
render patternLines rules =
    if rules.blockWidth == 0 || rules.blockHeight == 0 then
        []

    else
        let
            blankBlock =
                List.repeat rules.blockHeight (String.repeat rules.blockWidth " ")

            charToBlock c =
                Dict.get c rules.mapping
                    |> Maybe.withDefault blankBlock

            renderLine line =
                line
                    |> String.toList
                    |> List.map charToBlock
                    |> stitchRow
        in
        List.concatMap renderLine patternLines


init : Model
init =
    let
        rulesExample =
            "\\\n\\/\n \\\n\n/\n  /\n\\/\n/"
    in
    { rules = parse rulesP rulesExample
    , rulesInput = rulesExample
    , seedInput = "\\/"
    , dirty = True
    , pattern = []
    }


update : Msg -> Model -> Model
update msg m =
    case msg of
        EditRules i ->
            { m | rulesInput = i, rules = parse rulesP i, dirty = True }

        EditSeed i ->
            { m | seedInput = i, dirty = True }

        Step ->
            let
                applyRender pat =
                    case m.rules of
                        Ok rules ->
                            render pat rules

                        Err _ ->
                            pat
            in
            if m.dirty then
                let
                    seedLines =
                        String.lines m.seedInput

                    maxSeedWidth =
                        seedLines
                            |> List.map String.length
                            |> List.maximum
                            |> Maybe.withDefault 0

                    paddedSeed =
                        List.map (String.padRight maxSeedWidth ' ') seedLines
                in
                { m
                    | dirty = False
                    , pattern = applyRender paddedSeed
                }

            else
                case m.rules of
                    Ok rules ->
                        { m | pattern = render m.pattern rules }

                    Err _ ->
                        m


parse : Parser a -> String -> Result String a
parse p s =
    P.parse s p |> Result.mapError .message


ruleKeyP : Parser Char
ruleKeyP =
    P.when (\c -> c /= '\n' && c /= '\u{000D}')
        |> ignore (P.maybe (P.char '\u{000D}'))
        |> ignore (P.char '\n')


lineP : Parser String
lineP =
    P.stringWith (P.oneOrMore (P.when (\c -> c /= '\n' && c /= '\u{000D}')))
        |> ignore (P.maybe (P.char '\u{000D}'))
        |> ignore (P.maybe (P.char '\n'))


ruleP : Parser ( Char, List String )
ruleP =
    P.into Tuple.pair
        |> grab ruleKeyP
        |> grab (P.oneOrMore lineP)


blankLines : Parser ()
blankLines =
    P.zeroOrMore (P.oneOf [ P.char '\n', P.char '\u{000D}' ])
        |> P.map (\_ -> ())


rulesP : Parser Rules
rulesP =
    P.into Dict.fromList
        |> ignore blankLines
        |> grab (P.zeroOrMore (ruleP |> ignore blankLines))
        |> ignore P.end
        |> P.map normalizeRules



-- * Tests


suite : Test
suite =
    describe "Elm L-trees"
        [ describe "Rule parser"
            [ test "parses canonical README example" <|
                \_ ->
                    let
                        input =
                            "\\\n\\/\n \\\n\n/\n  /\n\\/\n/"

                        expected =
                            { blockWidth = 3
                            , blockHeight = 3
                            , mapping =
                                Dict.fromList
                                    [ ( '\\', [ "\\/ ", " \\ ", "   " ] )
                                    , ( '/', [ "  /", "\\/ ", "/  " ] )
                                    ]
                            }
                    in
                    Expect.equal (Ok expected) (parse rulesP input)
            , test "parses single rule with multi-line block" <|
                \_ ->
                    let
                        input =
                            "X\nABC\nDEF"

                        expected =
                            { blockWidth = 3
                            , blockHeight = 2
                            , mapping = Dict.fromList [ ( 'X', [ "ABC", "DEF" ] ) ]
                            }
                    in
                    Expect.equal (Ok expected) (parse rulesP input)
            , test "parses empty input" <|
                \_ ->
                    Expect.equal
                        (Ok { blockWidth = 0, blockHeight = 0, mapping = Dict.empty })
                        (parse rulesP "")
            , test "parses input with only blank lines" <|
                \_ ->
                    Expect.equal
                        (Ok { blockWidth = 0, blockHeight = 0, mapping = Dict.empty })
                        (parse rulesP "\n\n\n")
            , test "parses rules with extra separating blank lines and trailing newlines" <|
                \_ ->
                    let
                        input =
                            "\n\nX\n1\n\n\nY\n2\n\n"

                        expected =
                            { blockWidth = 1
                            , blockHeight = 1
                            , mapping =
                                Dict.fromList
                                    [ ( 'X', [ "1" ] )
                                    , ( 'Y', [ "2" ] )
                                    ]
                            }
                    in
                    Expect.equal (Ok expected) (parse rulesP input)
            , test "preserves leading whitespace in block lines" <|
                \_ ->
                    let
                        input =
                            "K\n  A\n   B\n C"

                        expected =
                            { blockWidth = 4
                            , blockHeight = 3
                            , mapping = Dict.fromList [ ( 'K', [ "  A ", "   B", " C  " ] ) ]
                            }
                    in
                    Expect.equal (Ok expected) (parse rulesP input)
            , test "fails on multi-character key line" <|
                \_ ->
                    Expect.err (parse rulesP "AB\nXYZ")
            , test "fails on key without block" <|
                \_ ->
                    Expect.err (parse rulesP "A\n")
            , test "fails on single character key without newline" <|
                \_ ->
                    Expect.err (parse rulesP "A")
            , test "fails on invalid key in subsequent rule" <|
                \_ ->
                    Expect.err (parse rulesP "A\n1\n\nBC\n2")
            , test "update handles EditRules message" <|
                \_ ->
                    let
                        newRulesInput =
                            "X\nABC"

                        cleanInit =
                            { init | dirty = False }

                        updated =
                            update (EditRules newRulesInput) cleanInit
                    in
                    Expect.all
                        [ \m -> Expect.equal newRulesInput m.rulesInput
                        , \m ->
                            Expect.equal
                                (Ok { blockWidth = 3, blockHeight = 1, mapping = Dict.fromList [ ( 'X', [ "ABC" ] ) ] })
                                m.rules
                        , \m -> Expect.equal True m.dirty
                        ]
                        updated
            , test "update handles EditSeed message" <|
                \_ ->
                    let
                        newSeedInput =
                            "/\\"

                        cleanInit =
                            { init | dirty = False }

                        updated =
                            update (EditSeed newSeedInput) cleanInit
                    in
                    Expect.all
                        [ \m -> Expect.equal newSeedInput m.seedInput
                        , \m -> Expect.equal True m.dirty
                        ]
                        updated
            ]
        , describe "normalizeRules"
            [ test "normalizes empty dictionary" <|
                \_ ->
                    Expect.equal
                        { blockWidth = 0, blockHeight = 0, mapping = Dict.empty }
                        (normalizeRules Dict.empty)
            , test "normalizes uneven widths and heights across multiple blocks" <|
                \_ ->
                    let
                        raw =
                            Dict.fromList
                                [ ( 'A', [ "1" ] )
                                , ( 'B', [ "123", "4" ] )
                                , ( 'C', [ "12", "3456", "7" ] )
                                ]

                        expected =
                            { blockWidth = 4
                            , blockHeight = 3
                            , mapping =
                                Dict.fromList
                                    [ ( 'A', [ "1   ", "    ", "    " ] )
                                    , ( 'B', [ "123 ", "4   ", "    " ] )
                                    , ( 'C', [ "12  ", "3456", "7   " ] )
                                    ]
                            }
                    in
                    Expect.equal expected (normalizeRules raw)
            , test "normalizes single rule with uneven line widths" <|
                \_ ->
                    let
                        raw =
                            Dict.fromList [ ( 'X', [ "A", "BCDEF", "G" ] ) ]

                        expected =
                            { blockWidth = 5
                            , blockHeight = 3
                            , mapping = Dict.fromList [ ( 'X', [ "A    ", "BCDEF", "G    " ] ) ]
                            }
                    in
                    Expect.equal expected (normalizeRules raw)
            ]
        , describe "Render engine"
            [ test "renders single-rule replacements" <|
                \_ ->
                    let
                        rules =
                            { blockWidth = 2
                            , blockHeight = 2
                            , mapping = Dict.fromList [ ( 'X', [ "AB", "CD" ] ) ]
                            }
                    in
                    Expect.equal [ "ABAB", "CDCD" ] (render [ "XX" ] rules)
            , test "substitutes default space block for unmapped characters and whitespace" <|
                \_ ->
                    let
                        rules =
                            { blockWidth = 2
                            , blockHeight = 2
                            , mapping = Dict.fromList [ ( 'X', [ "AB", "CD" ] ) ]
                            }
                    in
                    Expect.equal [ "AB  ", "CD  " ] (render [ "X " ] rules)
            , test "returns empty list on zero dimension rules or empty pattern" <|
                \_ ->
                    let
                        emptyRules =
                            { blockWidth = 0, blockHeight = 0, mapping = Dict.empty }
                    in
                    Expect.all
                        [ \_ -> Expect.equal [] (render [ "X" ] emptyRules)
                        , \_ -> Expect.equal [] (render [] { blockWidth = 2, blockHeight = 2, mapping = Dict.empty })
                        ]
                        ()
            , test "renders canonical README example across consecutive steps" <|
                \_ ->
                    let
                        rulesInput =
                            "\\\n\\/\n \\\n\n/\n / \n/  "

                        rulesResult =
                            parse rulesP "\\\n\\/\n \\\n\n/\n /\n/\n"
                    in
                    case rulesResult of
                        Err err ->
                            Expect.fail ("Failed to parse rules: " ++ err)

                        Ok rules ->
                            let
                                step1 =
                                    render [ "\\/" ] rules

                                expectedStep1 =
                                    [ "\\/ /"
                                    , " \\/ "
                                    ]

                                step2 =
                                    render step1 rules

                                expectedStep2 =
                                    [ "\\/ /   /"
                                    , " \\/   / "
                                    , "  \\/ /  "
                                    , "   \\/   "
                                    ]
                            in
                            Expect.all
                                [ \_ -> Expect.equal expectedStep1 step1
                                , \_ -> Expect.equal expectedStep2 step2
                                ]
                                ()
            , test "renders multi-line input patterns vertically" <|
                \_ ->
                    let
                        rules =
                            { blockWidth = 2
                            , blockHeight = 2
                            , mapping =
                                Dict.fromList
                                    [ ( 'A', [ "11", "11" ] )
                                    , ( 'B', [ "22", "22" ] )
                                    ]
                            }
                    in
                    Expect.equal
                        [ "1122"
                        , "1122"
                        , "2211"
                        , "2211"
                        ]
                        (render [ "AB", "BA" ] rules)
            ]
        , describe "Step update"
            [ test "when dirty is True, re-seeds from padded seedInput, clears dirty, and renders pattern" <|
                \_ ->
                    let
                        model =
                            { rules =
                                Ok
                                    { blockWidth = 2
                                    , blockHeight = 2
                                    , mapping = Dict.fromList [ ( 'X', [ "11", "22" ] ) ]
                                    }
                            , rulesInput = "X\n11\n22"
                            , seedInput = "X\nXX"
                            , dirty = True
                            , pattern = [ "old" ]
                            }

                        updated =
                            update Step model
                    in
                    Expect.all
                        [ \m -> Expect.equal False m.dirty
                        , \m ->
                            -- Seed is padded to width 2: ["X ", "XX"]
                            -- 'X' -> "11"/"22", ' ' -> "  "/"  "
                            -- Row 1: "11  ", "22  "
                            -- Row 2: "1111", "2222"
                            Expect.equal [ "11  ", "22  ", "1111", "2222" ] m.pattern
                        ]
                        updated
            , test "when dirty is False, advances pattern by rendering from previous pattern" <|
                \_ ->
                    let
                        model =
                            { rules =
                                Ok
                                    { blockWidth = 2
                                    , blockHeight = 1
                                    , mapping = Dict.fromList [ ( '1', [ "22" ] ), ( '2', [ "33" ] ) ]
                                    }
                            , rulesInput = ""
                            , seedInput = "1"
                            , dirty = False
                            , pattern = [ "2" ]
                            }

                        updated =
                            update Step model
                    in
                    Expect.all
                        [ \m -> Expect.equal False m.dirty
                        , \m -> Expect.equal [ "33" ] m.pattern
                        ]
                        updated
            , test "when rules is Err, preserves padded seed on dirty step and leaves pattern on clean step" <|
                \_ ->
                    let
                        dirtyErrModel =
                            { rules = Err "Invalid rules"
                            , rulesInput = "invalid"
                            , seedInput = "A\nABC"
                            , dirty = True
                            , pattern = []
                            }

                        updatedDirty =
                            update Step dirtyErrModel

                        cleanErrModel =
                            { rules = Err "Invalid rules"
                            , rulesInput = "invalid"
                            , seedInput = "A"
                            , dirty = False
                            , pattern = [ "keep this" ]
                            }

                        updatedClean =
                            update Step cleanErrModel
                    in
                    Expect.all
                        [ \_ -> Expect.equal [ "A  ", "ABC" ] updatedDirty.pattern
                        , \_ -> Expect.equal False updatedDirty.dirty
                        , \_ -> Expect.equal [ "keep this" ] updatedClean.pattern
                        , \_ -> Expect.equal False updatedClean.dirty
                        ]
                        ()
            ]
        ]
